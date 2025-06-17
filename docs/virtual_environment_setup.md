# Virtual Environment Setup Guide

## Question
"Remind me how to set up and use a virtual environment"

## Answer

Here's how to set up and use a Python virtual environment:

### Create a virtual environment:
```bash
python -m venv venv
```
Or on some systems:
```bash
python3 -m venv venv
```

### Activate the virtual environment:

**On macOS/Linux:**
```bash
source venv/bin/activate
```

**On Windows:**
```bash
venv\Scripts\activate
```

### You'll know it's activated when you see:
```
(venv) ➜  search-tool
```

### Install dependencies:
```bash
pip install -r requirements.txt
```

### To deactivate when done:
```bash
deactivate
```

### Your workflow:
1. Always activate the venv before working: `source venv/bin/activate`
2. Run your commands: `python cli_v2.py list`
3. Deactivate when done: `deactivate`

### Tip for your alias:
You could update your `run` alias to use the venv Python directly:
```bash
alias run='./venv/bin/python cli_v2.py'
```
This way you don't need to activate the venv each time.