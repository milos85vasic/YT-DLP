FROM python:3.11-slim
WORKDIR /app
RUN pip install flask requests
COPY app.py .
COPY logo.png .
ENV METUBE_URL=http://metube-direct:8081
ENV PROXY_PORT=80
EXPOSE 80
CMD ["python", "app.py"]
