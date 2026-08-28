# Start from an official, slim Python image as our base
FROM python:3.13-slim

# Set the folder inside the container where our app will live
WORKDIR /app

# Copy just the dependency list first
COPY requirements.txt .

# Install the dependencies listed in that file
RUN pip install --no-cache-dir -r requirements.txt

# Now copy the rest of our application code into the container
COPY . .

# Create a non-root user and switch to it
RUN useradd --create-home appuser
USER appuser

# Tell Docker which port the app uses, and how to start it
EXPOSE 8000
CMD ["fastapi", "run", "main.py", "--host", "0.0.0.0", "--port", "8000"]