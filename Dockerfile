
#
#  Louis Mamakos <louie@transsys.com>
#  Philipp Hellmich <phil@hellmi.de>
#
#  Build a container to run the edgetpu flask daemon
#
#    docker build -t coral .
#
#  Run it something like:
#
#  docker run --restart=always --detach --name coral \
#          -p 5000:5000 --device /dev/bus/usb:/dev/bus/usb   coral:latest
#
#  It's necessary to pass in the /dev/bus/usb device to communicate with the USB stick.
#
#  You can use alternative models by putting them into a directory
#  that's mounted in the container, and then starting the container,
#  passing in environment variables MODEL and LABELS referring to
#  the files.

FROM ubuntu:18.04

WORKDIR /tmp

RUN apt-get update && apt-get install -y python3 wget curl unzip python3-pip

# downloading library file for edgetpu and install it
RUN wget --trust-server-names -O edgetpu_api.tar.gz  https://dl.google.com/coral/edgetpu_api/edgetpu_api_latest.tar.gz && \
    tar xzfz edgetpu_api.tar.gz && rm edgetpu_api.tar.gz && \
    cd edgetpu_api && \
    sed -i.orig  \
    	-e 's/^read USE_MAX_FREQ/USE_MAX_FREQ=y/' \
	-e 's/apt-get install/apt-get install --no-install-recommends/'  \
	-e '/^UDEV_RULE_PATH=/,/udevadm trigger/d'  \
    -e 's/^OS_VERSION=.*/OS_VERSION=Ubuntu/' \
      install.sh && \
    apt-get update && apt-get install sudo && \
    bash ./install.sh

# fetch the models.  maybe figure a way to conditionalize this?
# create models subdirectory for volume mount of custom models
RUN  mkdir /models && \
     chdir /models && \
     curl -q -O  https://dl.google.com/coral/canned_models/mobilenet_ssd_v2_coco_quant_postprocess_edgetpu.tflite  && \
     curl -q -O  https://dl.google.com/coral/canned_models/coco_labels.txt && \
     curl -q -O  https://dl.google.com/coral/canned_models/mobilenet_ssd_v2_face_quant_postprocess_edgetpu.tflite

RUN cd /tmp && \
    wget "https://github.com/robmarkcole/coral-pi-rest-server/archive/v0.9.zip" -O /tmp/server.zip && \
    unzip /tmp/server.zip && \
    mv coral-pi-rest-server-0.9 /app

WORKDIR /app

RUN  pip3 install --no-cache-dir -r requirements.txt 

ENV MODEL=mobilenet_ssd_v2_coco_quant_postprocess_edgetpu.tflite \
    LABELS=coco_labels.txt \
    MODELS_DIRECTORY=/models/

EXPOSE 5000

CMD  exec python3 coral-app.py --model  "${MODEL}" --labels "${LABELS}" --models_directory "${MODELS_DIRECTORY}"
