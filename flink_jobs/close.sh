# 一键关闭所有作业的脚本
curl -s "http://localhost:8081/jobs" | \
  python3 -c "
import json, sys, urllib.request, urllib.error
data = json.load(sys.stdin)
for job in data['jobs']:
    if job['status'] == 'RUNNING' or job['status'] == 'RESTARTING':
        job_id = job['id']
        print(f'正在关闭作业: {job_id}')
        try:
            req = urllib.request.Request(
                f'http://localhost:8081/jobs/{job_id}?mode=cancel',
                method='PATCH'
            )
            urllib.request.urlopen(req)
        except Exception as e:
            print(f'关闭作业 {job_id} 失败: {e}')
"