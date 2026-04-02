"""FastAPI application for sample_cicd project."""

from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def root() -> dict[str, str]:
    """Return Hello World message.

    Returns:
        JSON response with greeting message.
    """
    return {"message": "Hello, World!"}


@app.get("/health")
def health() -> dict[str, str]:
    """Health check endpoint for ALB target group.

    Returns:
        JSON response with health status.
    """
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
