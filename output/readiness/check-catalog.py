import json, hashlib, struct, concurrent.futures, subprocess
from pathlib import Path
base='https://lists.roxuh.com/v1/catalog.json'
raw=subprocess.check_output(['curl','-fLsS','--max-time','30',base])
print('Catalog HTTPS fetch succeeded with curl')
catalog=json.loads(raw)
Path('output/readiness/live-catalog.json').write_bytes(raw)
print('Generated:',catalog['generatedAt'])
def check(e):
    data=subprocess.check_output(['curl','-fLsS','--max-time','45',e['file']])
    values=[x[0] for x in struct.iter_unpack('<Q',data)]
    ok=hashlib.sha256(data).hexdigest()==e['sha256'] and len(data)==e['bytes'] and len(values)==e['domainCount'] and all(a<b for a,b in zip(values,values[1:]))
    return dict(id=e['id'],valid=ok,domains=len(values),updated=e['updatedAt'])
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
    for result in pool.map(check,catalog['lists']): print(result)
