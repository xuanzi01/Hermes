# 飞书多维表格（Bitable）API 实测记录

## 基础信息

- 多维表格 App Token: `CCHCbO58UaRT9vsVUw1cwinlnIg`
- 账号列表表 ID: `tbl050boeWpWPwuL`
- Skills 清单表 ID: `tbl34KMyprg4Lvqk`（2026-06-02 新建，已删除）

## 云盘内创建 Base ✅ 正确方案

**2026-06-02 实测确认**：把多维表格创建在**云盘（AI知识库）文件夹**下，tenant token 可以正常写入 tables、fields 和 records。

### 操作步骤

1. 获取云盘 folder_token（通过 `GET /open-apis/drive/v1/files`）
2. 创建 base 时指定 `folder_token`：`POST /open-apis/bitable/v1/apps` body: `{"name": "表名", "folder_token": "xxx"}`
3. 在这个 base 下创建的表，tenant token 可以正常写入记录

### 已验证成功的 base

- Base Token: `EfctboZDma3FFRslEfKc3haTnO8`
- Table: `tbl5uJ6ePNjf5Hfh`
- URL: `https://my.feishu.cn/base/EfctboZDma3FFRslEfKc3haTnO8`
- 位置: 飞书云盘 → AI知识库

### Python 脚本模板

```python
import urllib.request, json, time

with open('/opt/data/home/.lark-cli/hermes/config.json') as f:
    config = json.load(f)
app_id = config['apps'][0]['appId']
app_secret = config['apps'][0]['appSecret']

# 获取 tenant token
req = urllib.request.Request(
    'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal',
    data=json.dumps({"app_id": app_id, "app_secret": app_secret}).encode(),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
with urllib.request.urlopen(req) as resp:
    tenant_token = json.loads(resp.read()).get('tenant_access_token')

headers = {'Content-Type': 'application/json', 'Authorization': f'Bearer {tenant_token}'}
base_token = "<new_base_token>"
table_id = "<table_id>"

# 写入记录
req_rec = urllib.request.Request(
    f'https://open.feishu.cn/open-apis/bitable/v1/apps/{base_token}/tables/{table_id}/records/batch_create',
    data=json.dumps({"records": [{"fields": {"多行文本": "test"}}]}).encode(),
    headers=headers,
    method='POST'
)
with urllib.request.urlopen(req_rec) as resp:
    print(json.loads(resp.read()).get('msg'))
```

---

## 个人空间创建 Base ❌ 失败方案

**在个人空间直接创建 base → tenant/user token 都无法写 records（403 91403）**

- 这不是 API 权限问题，不需要去飞书开放平台加权限
- 根因：个人空间 base 与应用 token 之间存在飞书安全隔离
- 应用无法写入个人空间的 base，即使 OAuth scope 包含 `base:record:create`

---

## API 访问控制矩阵（个人空间 Base）

| 操作 | Tenant Token | User Token (lark-cli --as user) | 状态 |
|------|-------------|--------------------------------|------|
| 列出 tables | ✅ | ✅ | 成功 |
| 创建 table | ✅ | ✅ | 成功 |
| 列出 fields | ✅ | ✅ | 成功 |
| 创建 field | ✅ | ✅ | 成功 |
| **创建 record** | ❌ 403 (91403) | ❌ 403 (91403) | **失败** |
| 删除 table | ❌ | ✅ | |

---

## 创建多维表格的正确字段格式

创建字段时必须指定正确的 type：

| 字段类型 | type 值 | ui_type |
|---------|---------|---------|
| 文本 | 1 | Text |
| 单选 | 3 | SingleSelect |
| 多选 | 4 | MultiSelect |
| 数字 | 2 | Number |
| 日期 | 5 | Date |
| 复选框 | 7 | Checkbox |
| 关联 | 17 | LookUp |
| 公式 | 20 | Formula |

---

## `--data @file.json` 的 lark-cli 限制

- ❌ 不接受绝对路径（`/tmp/record.json`）
- ✅ 只接受相对路径（`./record.json`），且必须在当前工作目录
- ✅ `--data '{"json": true}'` 内联 JSON 可以

**结论**：直接调 REST API（Python/curl）比 lark-cli 更可靠

---

## 已知 bug 汇总

| bug | 说明 | 解决方案 |
|-----|------|---------|
| PATCH field 返回 404 | tenant token 下修复字段名不工作 | 直接重建字段，不修复 |
| records 写入 403 | 个人空间 base 的安全隔离 | 把 base 建在云盘文件夹 |
| PUT field 返回 400 | 必须同时传 field_name + type + is_primary | 用 PATCH（但 PATCH 有 404 bug）|
| 新表主字段名乱码 | `tbl5uJ6ePNjf5Hfh` 主字段为"多行文本" | 重命名用 POST 新字段代替 |

---

最后更新：2026-06-02