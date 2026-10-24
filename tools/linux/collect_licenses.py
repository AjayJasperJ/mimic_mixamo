"""Preserve installed Python dependency license/notice files in the AppImage."""
from importlib import metadata
from pathlib import Path
import shutil
import sys

out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
for distribution in metadata.distributions():
    name=distribution.metadata.get('Name','unknown')
    for entry in distribution.files or []:
        upper=str(entry).upper()
        if any(x in upper for x in ['LICENSE','LICENCE','COPYING','NOTICE']):
            source=Path(distribution.locate_file(entry))
            if source.is_file():
                target=out/name/Path(str(entry).replace('..','_'))
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(source,target)
