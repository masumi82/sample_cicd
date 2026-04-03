# DB 設計書

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 1.0 |

## 1. データベース概要

| 項目 | 値 |
|------|------|
| DB エンジン | PostgreSQL 15 |
| インスタンスクラス | db.t3.micro |
| ストレージ | 20 GB (gp2) |
| 配置 | プライベートサブネット（Single-AZ） |
| データベース名 | sample_cicd |
| ポート | 5432 |

## 2. テーブル定義

### 2.1 tasks テーブル

| カラム名 | データ型 | 制約 | 説明 |
|----------|----------|------|------|
| id | SERIAL | PRIMARY KEY | タスク ID（自動採番） |
| title | VARCHAR(255) | NOT NULL | タスクのタイトル |
| description | TEXT | NULL 許容 | タスクの説明 |
| completed | BOOLEAN | NOT NULL, DEFAULT FALSE | 完了フラグ |
| created_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | 更新日時 |

### 2.2 DDL

```sql
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 2.3 インデックス

| インデックス名 | カラム | 種類 | 備考 |
|----------------|--------|------|------|
| tasks_pkey | id | PRIMARY KEY | 自動作成 |

> **設計判断:** 学習用プロジェクトのため、追加インデックスは設けない。
> タスク数が少量であり、パフォーマンス問題は発生しない。

## 3. SQLAlchemy モデル設計

### 3.1 Task モデル（models.py）

```python
class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=func.now(), onupdate=func.now()
    )
```

### 3.2 DB 接続設定（database.py）

```python
# DATABASE_URL construction from environment variables:
# DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD
# → postgresql://DB_USERNAME:DB_PASSWORD@DB_HOST:DB_PORT/DB_NAME

# Engine: create_engine(DATABASE_URL)
# SessionLocal: sessionmaker(bind=engine)
# Base: declarative_base()
# get_db(): Dependency injection for FastAPI
```

**環境変数:**

| 変数名 | 説明 | 注入方法 |
|--------|------|----------|
| DB_HOST | RDS エンドポイント | Secrets Manager → ECS secrets |
| DB_PORT | DB ポート (5432) | Secrets Manager → ECS secrets |
| DB_NAME | データベース名 | Secrets Manager → ECS secrets |
| DB_USERNAME | DB ユーザー名 | Secrets Manager → ECS secrets |
| DB_PASSWORD | DB パスワード | Secrets Manager → ECS secrets |
| DATABASE_URL | テスト用（直接指定） | ローカル / テスト環境のみ |

**接続ロジック:**
1. `DATABASE_URL` 環境変数が設定されている場合はそれを使用（テスト用）
2. 未設定の場合は `DB_*` 環境変数から組み立て（本番用）

## 4. Pydantic スキーマ設計（schemas.py）

```python
class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = None

class TaskUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    completed: bool | None = None

class TaskResponse(BaseModel):
    id: int
    title: str
    description: str | None
    completed: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
```

## 5. マイグレーション戦略

### 5.1 ツール

Alembic を使用してマイグレーションを管理する。

### 5.2 ディレクトリ構成

```
app/
├── alembic.ini              # Alembic 設定ファイル
└── alembic/
    ├── env.py               # 環境設定（SQLAlchemy Base を読み込む）
    └── versions/
        └── 001_create_tasks_table.py  # 初回マイグレーション
```

### 5.3 マイグレーションファイル

**001_create_tasks_table.py:**

```python
def upgrade():
    op.create_table(
        "tasks",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("completed", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime, nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime, nullable=False, server_default=sa.func.now()),
    )

def downgrade():
    op.drop_table("tasks")
```

### 5.4 マイグレーション実行方法

**ローカル:**

```bash
cd app
alembic upgrade head
```

**デプロイ時:**

ECS タスク起動後、アプリケーション側で起動時にマイグレーションを実行する。
`main.py` のスタートアップイベントで `alembic upgrade head` 相当の処理を行う。

> **設計判断:** ECS Fargate ではコンテナ起動時にマイグレーションを実行する。
> 別途マイグレーション用の ECS タスクを立てる方式もあるが、
> 学習用プロジェクトのため、アプリケーション起動時に自動実行するシンプルな方式を採用。

## 6. テスト用 DB 設計

### 6.1 テスト戦略

テストでは RDS PostgreSQL ではなく **SQLite インメモリデータベース** を使用する。

| 環境 | DB | 接続方法 |
|------|------|----------|
| 本番（ECS） | PostgreSQL (RDS) | Secrets Manager → 環境変数 |
| ローカル開発 | PostgreSQL (ローカル) | DATABASE_URL 環境変数 |
| テスト | SQLite (インメモリ) | `sqlite:///` を直接指定 |

### 6.2 テスト用 DB セットアップ（conftest.py）

```python
# Test database: SQLite in-memory
# Override get_db dependency with test session
# Create all tables before each test
# Drop all tables after each test
```

> **設計判断:** SQLite を使用する理由:
> - テスト実行に外部依存（PostgreSQL）が不要
> - CI 環境でも追加セットアップなしで実行可能
> - 本プロジェクトでは PostgreSQL 固有機能を使用しないため互換性の問題なし
