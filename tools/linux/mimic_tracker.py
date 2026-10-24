#!/usr/bin/env python3
"""Private stdio webcam worker. One frame per credit, no server, recording or upload."""
import argparse
import base64
import glob
import hashlib
import json
import os
from pathlib import Path
import signal
import sys
import time
import uuid

MODEL_SHA256 = '59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a'
HAND_MODEL_SHA256 = 'fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1'


def devices():
    result=[]
    for path in sorted(glob.glob('/dev/video*')):
        node=Path(path).name
        try:
            name=Path('/sys/class/video4linux',node,'name').read_text().strip()
        except OSError:
            name=node
        result.append({'path':path,'name':f'{name} ({node})'})
    return result


def emit(value):
    sys.stdout.write(json.dumps(value,separators=(',',':'),allow_nan=False)+'\n')
    sys.stdout.flush()


def default_model():
    # PyInstaller onedir puts added data in _internal, represented by _MEIPASS.
    bundled=Path(getattr(sys,'_MEIPASS',Path(__file__).resolve().parent))/'pose_landmarker_lite.task'
    if bundled.is_file():
        return bundled
    # `flutter run -d linux` uses the source worker. The model fetch script
    # stores its development copy in the committed local plugin's asset tree.
    source=Path(__file__).resolve().parents[2]/'app/packages/mimic_native/android/src/main/assets/pose_landmarker_lite.task'
    return source if source.is_file() else bundled


def default_hand_model():
    bundled=Path(getattr(sys,'_MEIPASS',Path(__file__).resolve().parent))/'hand_landmarker.task'
    if bundled.is_file(): return bundled
    source=Path(__file__).resolve().parents[2]/'app/packages/mimic_native/android/src/main/assets/hand_landmarker.task'
    return source if source.is_file() else bundled


def hand_points(result, pose):
    """Associate each detected hand with the nearest visible anatomical pose wrist."""
    output={'leftHandWorld':[],'rightHandWorld':[],
            'leftHandPoints':[],'rightHandPoints':[]}
    if not pose: return output
    wrists=[pose[15],pose[16]]
    candidates=[]
    for i,landmarks in enumerate(result.hand_landmarks):
        if not landmarks: continue
        wrist=landmarks[0]
        distances=[((wrist.x-p.x)**2+(wrist.y-p.y)**2)**.5 if p.visibility >= .35 else 10 for p in wrists]
        side=min(range(2),key=lambda j:distances[j])
        if distances[side] < .25:
            candidates.append((distances[side],side,i))
    used=set()
    for _,side,i in sorted(candidates):
        if side in used: continue
        used.add(side)
        points=result.hand_world_landmarks[i]
        if len(points)==21:
            output['leftHandWorld' if side==0 else 'rightHandWorld']=[
                {'x':float(p.x),'y':float(p.y),'z':float(p.z)} for p in points]
            image_points=result.hand_landmarks[i]
            output['leftHandPoints' if side==0 else 'rightHandPoints']=[
                {'x':float(p.x),'y':float(p.y),'z':float(p.z)} for p in image_points]
    return output


def run(args):
    # Leave device enumeration dependency-free and do not open cameras while listing.
    if args.list_devices:
        emit({'kind':'devices','devices':devices()})
        return
    os.environ.setdefault('MPLBACKEND','Agg')
    os.environ.setdefault('OPENCV_LOG_LEVEL','ERROR')
    import cv2
    import numpy as np
    import mediapipe as mp
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision
    model=Path(args.model or default_model())
    digest=hashlib.sha256(model.read_bytes()).hexdigest()
    if digest!=MODEL_SHA256:
        raise ValueError('Bundled tracking model checksum mismatch')
    hand_model=Path(args.hand_model or default_hand_model())
    hand_digest=hashlib.sha256(hand_model.read_bytes()).hexdigest()
    if hand_digest!=HAND_MODEL_SHA256:
        raise ValueError('Bundled hand tracking model checksum mismatch')
    options=vision.PoseLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_path=str(model)),
        running_mode=vision.RunningMode.VIDEO,num_poses=1,
        min_pose_detection_confidence=.5,min_pose_presence_confidence=.5,
        min_tracking_confidence=.5,output_segmentation_masks=False)
    hand_options=vision.HandLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_path=str(hand_model)),
        running_mode=vision.RunningMode.VIDEO,num_hands=2,
        min_hand_detection_confidence=.5,min_hand_presence_confidence=.5,
        min_tracking_confidence=.5)
    cap=None
    with vision.PoseLandmarker.create_from_options(options) as detector, vision.HandLandmarker.create_from_options(hand_options) as hands:
        if args.self_test:
            frame=np.zeros((480,640,3),dtype=np.uint8)
            image=mp.Image(image_format=mp.ImageFormat.SRGB,data=frame)
            result=detector.detect_for_video(image,1)
            hand_result=hands.detect_for_video(image,1)
            ok,jpeg=cv2.imencode('.jpg',frame)
            if not ok: raise RuntimeError('JPEG encoding failed')
            emit({'kind':'self-test','ok':True,'modelSha256':digest,
                  'detectedPoses':len(result.pose_landmarks),'jpegBytes':len(jpeg),
                  'handModelSha256':hand_digest,'detectedHands':len(hand_result.hand_landmarks),
                  'source':'synthetic blank fixture; not a camera accuracy test'})
            return
        if not args.device.startswith('/dev/video') or not args.device[10:].isdigit():
            raise ValueError('Select a /dev/video<number> webcam')
        cap=cv2.VideoCapture(args.device,cv2.CAP_V4L2)
        try:
            if not cap.isOpened():
                raise RuntimeError(f'Cannot open {args.device}. Check webcam permissions or close another camera app.')
            cap.set(cv2.CAP_PROP_FRAME_WIDTH,640)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT,480)
            cap.set(cv2.CAP_PROP_FPS,30)
            cap.set(cv2.CAP_PROP_BUFFERSIZE,1)
            session=uuid.uuid4().hex
            emit({'kind':'ready','device':args.device,'schemaVersion':3,'sessionId':session})
            sequence=0
            previous=-1
            for command in sys.stdin:
                if command.strip()=='stop': break
                if command.strip()!='next': continue
                ok,frame=cap.read()
                if not ok: raise RuntimeError('Webcam stopped delivering frames. Try a different video device.')
                # Inference receives anatomical/unmirrored pixels. Mirror is a display policy.
                rgb=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB)
                timestamp=max(previous+1,time.monotonic_ns()//1_000_000)
                previous=timestamp
                started=time.monotonic_ns()
                detected=detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,data=rgb),timestamp)
                hand_detected=hands.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,data=rgb),timestamp)
                latency=(time.monotonic_ns()-started)//1_000_000
                points=[{'x':float(p.x),'y':float(p.y),'z':float(p.z),'visibility':p.visibility,'presence':p.presence}
                        for p in (detected.pose_landmarks[0] if detected.pose_landmarks else [])]
                world=[{'x':float(p.x),'y':float(p.y),'z':float(p.z),'visibility':p.visibility,'presence':p.presence}
                       for p in (detected.pose_world_landmarks[0] if detected.pose_world_landmarks else [])]
                # Landmarks and the JPEG are always from the same processed frame.
                ok,jpeg=cv2.imencode('.jpg',frame,[cv2.IMWRITE_JPEG_QUALITY,75])
                if not ok: raise RuntimeError('JPEG encoding failed')
                sequence+=1
                hand_data=hand_points(hand_detected,detected.pose_landmarks[0] if detected.pose_landmarks else [])
                emit({'kind':'frame','schemaVersion':3,'sessionId':session,'sequence':sequence,'capturedAtUs':timestamp*1000,'worldPoints':world,**hand_data,'jpeg':base64.b64encode(jpeg).decode('ascii'),
                      'width':int(frame.shape[1]),'height':int(frame.shape[0]),
                      'points':points,'frames':sequence,'inferenceMs':latency,
                      'device':args.device})
        finally:
            cap.release()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--list-devices',action='store_true')
    parser.add_argument('--self-test',action='store_true')
    parser.add_argument('--model')
    parser.add_argument('--hand-model')
    parser.add_argument('--device',default='/dev/video0')
    args=parser.parse_args()
    try:
        run(args)
    except (BrokenPipeError,KeyboardInterrupt):
        pass
    except Exception as error:
        emit({'kind':'error','message':str(error)})
        sys.exit(1)


if __name__=='__main__':
    main()
