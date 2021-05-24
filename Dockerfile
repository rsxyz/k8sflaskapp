FROM python:3.9-alpine3.13

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
ENV FLASK_APP app.py
COPY . /app/
EXPOSE 8080
ENTRYPOINT [ "python" ]
CMD [ "app.py" ]
