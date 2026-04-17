FROM python:3.13-slim

WORKDIR /srv/app
ARG FIXTURE_MESSAGE_SUFFIX=default
ENV FIXTURE_MESSAGE_SUFFIX=${FIXTURE_MESSAGE_SUFFIX}
COPY app/ app/
ENV PYTHONPATH=/srv/app/app
CMD ["python", "-c", "import os, greetings; print(f'{greetings.hello()} [{os.environ.get(\"FIXTURE_MESSAGE_SUFFIX\", \"default\")}]')"]
