from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess,json
root=Path(__file__).resolve().parents[1]/'output/charles-localized'
py='/home/user/.cache/charles-screenshots-venv/bin/python'
helper='/home/user/.codex/skills/charles-store-screenshots/scripts/shots.py'
def run(d):
 p=subprocess.run([py,helper,'render',str(d/'set.html'),'--scale','3'],capture_output=True,text=True)
 (d/'render.log').write_text(p.stdout+p.stderr)
 return {'locale':d.name,'exit':p.returncode,'problems':[l for l in (p.stdout+p.stderr).splitlines() if 'PROBLEM' in l or 'CHECK' in l]}
with ThreadPoolExecutor(max_workers=2) as pool:
 results=list(pool.map(run,sorted(d for d in root.iterdir() if (d/'set.html').exists())))
(root/'render-report.json').write_text(json.dumps(results,indent=2))
print(json.dumps({'locales':len(results),'failed':[x for x in results if x['exit'] or x['problems']]}))
