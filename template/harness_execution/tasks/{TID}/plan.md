# {TID} {title} Implementation Plan

> 生成方式：plan-generator skill。

## File Structure

```text
（本 task 要创建/修改的文件树）
```

## 全局约束

{spec 中跨 task 的要求——版本下限、依赖限制、命名规则——每行一条}

---

## Task 1: {子步骤标题}

**文件：**
- 创建: `exact/path/to/file.py`
- 修改: `exact/path/to/existing.py`
- 测试: `tests/exact/path/to/test.py`

**接口：**
- 消费: {这个 step 使用前面 step 的什么}
- 产出: {后面 step 依赖什么}

- [ ] **Step 1: 写失败的测试**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: 跑测试验证失败**

运行: `pytest tests/path/test.py::test_name -v`
期望: FAIL

- [ ] **Step 3: 写最小实现**

```python
def function(input):
    return expected
```

- [ ] **Step 4: 跑测试验证通过**

运行: `pytest tests/path/test.py::test_name -v`
期望: PASS

- [ ] **Step 5: 提交**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat({TID}): add specific feature"
```

## Task 2: ...

## Self-Review Checklist

- [ ] 测试覆盖验收标准
- [ ] 无硬编码 secret
- [ ] 遵循 ref 约定
