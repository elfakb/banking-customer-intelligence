import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()

password = os.getenv("DB_PASSWORD", "")
auth = f"{os.getenv('DB_USER')}:{password}" if password else os.getenv("DB_USER")

url = (
    f"postgresql+psycopg2://{auth}"
    f"@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
)

engine = create_engine(url)

with engine.connect() as conn:
    version = conn.execute(text("SELECT version();")).scalar()
    print("Connection successful!")
    print(version)