# daemon runs in the background
# run something like tail /var/log/turtlecoind/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/turtlecoind:/var/lib/turtlecoind -v $(pwd)/wallet:/home/turtlecoin --rm -ti turtlecoin:0.2.2
FROM ubuntu:16.04

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG TURTLECOIN_VERSION=v0.2.2

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
      libboost1.58-all-dev \
      librocksdb-dev && \
    git clone https://github.com/turtlecoin/turtlecoin.git /src/turtlecoin && \
    cd /src/turtlecoin && \
    git checkout $TURTLECOIN_VERSION && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/TurtleCoind /usr/local/bin/TurtleCoind && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/simplewallet /usr/local/bin/simplewallet && \
    cp src/miner /usr/local/bin/miner && \
    cp src/connectivity_tool /usr/local/bin/connectivity_tool && \
    strip /usr/local/bin/TurtleCoind && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/simplewallet && \
    strip /usr/local/bin/miner && \
    strip /usr/local/bin/connectivity_tool && \
    cd / && \
    rm -rf /src/turtlecoin && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev librocksdb-dev && \
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

# setup the turtlecoind service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/turtlecoind turtlecoind && \
    useradd -s /bin/bash -m -d /home/turtlecoin turtlecoin && \
    mkdir -p /etc/services.d/turtlecoind/log && \
    mkdir -p /var/log/turtlecoind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/turtlecoind/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/turtlecoind/run && \
    echo "cd /var/lib/turtlecoind" >> /etc/services.d/turtlecoind/run && \
    echo "export HOME /var/lib/turtlecoind" >> /etc/services.d/turtlecoind/run && \
    echo "s6-setuidgid turtlecoind /usr/local/bin/TurtleCoind" >> /etc/services.d/turtlecoind/run && \
    chmod +x /etc/services.d/turtlecoind/run && \
    chown nobody:nogroup /var/log/turtlecoind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/turtlecoind/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/turtlecoind/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/turtlecoind" >> /etc/services.d/turtlecoind/log/run && \
    chmod +x /etc/services.d/turtlecoind/log/run && \
    echo "/var/lib/turtlecoind true turtlecoind 0644 0755" > /etc/fix-attrs.d/turtlecoind-home && \
    echo "/home/turtlecoin true turtlecoin 0644 0755" > /etc/fix-attrs.d/turtlecoin-home && \
    echo "/var/log/turtlecoind true nobody 0644 0755" > /etc/fix-attrs.d/turtlecoind-logs

VOLUME ["/var/lib/turtlecoind", "/home/turtlecoin","/var/log/turtlecoind"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/turtlecoin export HOME /home/turtlecoin s6-setuidgid turtlecoin /bin/bash"]
