# daemon runs in the background
# run something like tail /var/log/GalacticBitsd/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/GalacticBitsd:/var/lib/GalacticBitsd -v $(pwd)/wallet:/home/GalacticBits --rm -ti GalacticBits:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG GalacticBits_BRANCH=master
ENV GalacticBits_BRANCH=${GalacticBits_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/GalacticBits/GalacticBits.git /src/GalacticBits && \
    cd /src/GalacticBits && \
    git checkout $GalacticBits_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/GalacticBitsd /usr/local/bin/GalacticBitsd && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/GalacticBitsd && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/GalacticBits && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the GalacticBitsd service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/GalacticBitsd GalacticBitsd && \
    useradd -s /bin/bash -m -d /home/GalacticBits GalacticBits && \
    mkdir -p /etc/services.d/GalacticBitsd/log && \
    mkdir -p /var/log/GalacticBitsd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/GalacticBitsd/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/GalacticBitsd/run && \
    echo "cd /var/lib/GalacticBitsd" >> /etc/services.d/GalacticBitsd/run && \
    echo "export HOME /var/lib/GalacticBitsd" >> /etc/services.d/GalacticBitsd/run && \
    echo "s6-setuidgid GalacticBitsd /usr/local/bin/GalacticBitsd" >> /etc/services.d/GalacticBitsd/run && \
    chmod +x /etc/services.d/GalacticBitsd/run && \
    chown nobody:nogroup /var/log/GalacticBitsd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/GalacticBitsd/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/GalacticBitsd/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/GalacticBitsd" >> /etc/services.d/GalacticBitsd/log/run && \
    chmod +x /etc/services.d/GalacticBitsd/log/run && \
    echo "/var/lib/GalacticBitsd true GalacticBitsd 0644 0755" > /etc/fix-attrs.d/GalacticBitsd-home && \
    echo "/home/GalacticBits true GalacticBits 0644 0755" > /etc/fix-attrs.d/GalacticBits-home && \
    echo "/var/log/GalacticBitsd true nobody 0644 0755" > /etc/fix-attrs.d/GalacticBitsd-logs

VOLUME ["/var/lib/GalacticBitsd", "/home/GalacticBits","/var/log/GalacticBitsd"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/GalacticBits export HOME /home/GalacticBits s6-setuidgid GalacticBits /bin/bash"]
