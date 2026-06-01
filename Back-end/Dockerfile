# Use a lightweight Python base image
FROM python:3.11-slim

# Set the working directory
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application code
COPY . .

# Expose the port (Cloud Run sets the PORT env var)
ENV PORT=8080

# Start the FastAPI server using Uvicorn
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT}