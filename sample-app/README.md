# Sample Python App

Simple Flask application for demonstrating Jenkins CI/CD pipeline.

## Local Development

```bash
cd sample-app
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Visit http://localhost:5000

## Run Tests

```bash
pytest -v test_app.py
```

## Production Deployment

See main README.md for Jenkins pipeline and manual deployment instructions.
