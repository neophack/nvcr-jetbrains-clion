#################################################
# SmartIDE Developer Container Image
# Licensed under GPL v3.0
# Copyright (C) leansoftX.com
#################################################

FROM ubuntu:20.04 AS ideDownloader
# -------------下载IDE文件
# prepare tools:
RUN apt-get update && apt-get -y install --no-install-recommends wget ca-certificates tar
# download IDE to the /ide dir:
WORKDIR /download

# https://download.jetbrains.com/idea/ideaIC-2021.2.3.tar.gz
ARG downloadUrl=https://download.jetbrains.com/go/goland-2020.3.5.tar.gz
RUN wget -q $downloadUrl -O - | tar -xz
RUN find . -maxdepth 1 -type d -name * -execdir mv {} /ide \;

# -------------构建projector-server库，运行依赖
FROM smartide/projector-server:latest as projectorGradleBuilder


# -------------处理IDE运行程序，和构建好的rojector-server库
FROM ubuntu:20.04 AS projectorStaticFiles

# prepare tools:
RUN apt-get update && apt-get -y install --no-install-recommends unzip
# create the Projector dir:
ENV PROJECTOR_DIR /projector
RUN mkdir -p $PROJECTOR_DIR
# copy IDE:
COPY --from=ideDownloader /ide $PROJECTOR_DIR/ide
# copy projector files to the container:
COPY static $PROJECTOR_DIR
# copy projector:
COPY --from=projectorGradleBuilder $PROJECTOR_DIR/projector-server/projector-server/build/distributions/projector-server.zip $PROJECTOR_DIR
# prepare IDE - apply projector-server:
RUN unzip $PROJECTOR_DIR/projector-server.zip
RUN rm $PROJECTOR_DIR/projector-server.zip
RUN find . -maxdepth 1 -type d -name projector-server-* -exec mv {} projector-server \;
RUN mv projector-server $PROJECTOR_DIR/ide/projector-server
RUN mv $PROJECTOR_DIR/ide-projector-launcher.sh $PROJECTOR_DIR/ide/bin
RUN chmod 644 $PROJECTOR_DIR/ide/projector-server/lib/*


FROM opencv-gpu-cuda-11-r:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ Asia/Shanghai
#git中文乱码问题
ENV LESSCHARSET=utf-8

ENV DISPLAY ":1"
ENV VNC_PW "vncpassword"

ENV PROJECTOR_USER_NAME ide

RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-backports main restricted universe multiverse" >> /etc/apt/sources.list 

RUN true \
# Any command which returns non-zero exit code will cause this shell script to exit immediately:
   && set -e \
# Activate debugging to show execution details: all commands will be printed before execution
   && set -x \
# install packages:
    && apt-get update \
# packages for awt:
    && apt-get install --no-install-recommends libxext6 libxrender1 libxtst6 libxi6 libfreetype6 -y \
# packages for user convenience:
    && apt-get install --no-install-recommends git wget curl bash-completion net-tools sudo ca-certificates procps -y \
# clean apt to reduce image size:
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt

# "https://download.jetbrains.com/idea/ideaIC-2021.2.3.tar.gz"
#ARG downloadUrl

# RUN true \
# # 返回非零退出代码的任何命令都将导致此shell脚本立即退出：
#     && set -e \
# # 激活调试以显示执行详细信息：在执行之前将打印所有命令
#     && set -x \
# # 为IDE安装特定包：
#     && apt-get update \
#     && apt-get install build-essential clang -y \
# # clean apt to reduce image size:
#     && rm -rf /var/lib/apt/lists/* \
#     && rm -rf /var/cache/apt

# copy the Projector dir:
ENV PROJECTOR_DIR /projector
COPY --from=projectorStaticFiles $PROJECTOR_DIR $PROJECTOR_DIR


RUN true \
# Any command which returns non-zero exit code will cause this shell script to exit immediately:
    && set -e \
# Activate debugging to show execution details: all commands will be printed before execution
    && set -x \
# change user to non-root (http://pjdietz.com/2016/08/28/nginx-in-docker-without-root.html):
    # && mv $PROJECTOR_DIR/$PROJECTOR_USER_NAME /home \
    && chmod g+rw /home && mkdir -p /home/$PROJECTOR_USER_NAME && mkdir -p /home/project \
    && useradd -d /home/$PROJECTOR_USER_NAME -s /bin/bash -G sudo $PROJECTOR_USER_NAME \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && chown -R $PROJECTOR_USER_NAME.$PROJECTOR_USER_NAME /home/$PROJECTOR_USER_NAME \
    && chown -R $PROJECTOR_USER_NAME.$PROJECTOR_USER_NAME /home/project \
    && chown -R $PROJECTOR_USER_NAME.$PROJECTOR_USER_NAME $PROJECTOR_DIR/ide/bin \
# move run scipt:
    && mv $PROJECTOR_DIR/run.sh /home/$PROJECTOR_USER_NAME/run.sh \
    && chmod +x /home/$PROJECTOR_USER_NAME/run.sh  && chmod +x /projector/ide/bin/ide-projector-launcher.sh

# RUN apt-get update && \
#     apt-get -y install --no-install-recommends python3 net-tools curl git wget sudo gosu ca-certificates make libxss1 libsecret-1-dev && \
#     apt-get -y install --no-install-recommends libeigen3-dev fonts-wqy-microhei ttf-wqy-zenhei gdb gdbserver libceres-dev && \
#     apt-get clean && \
#     apt-get autoremove -y && \
#     rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# # Install VNC
# RUN \
#     # required for websockify
#     # apt-get install -y python-numpy  && \
#     cd ${RESOURCES_PATH} && \
#     # mv $PROJECTOR_DIR/novnc $PROJECTOR_DIR/novnc  && \
#     ln -s $PROJECTOR_DIR/novnc/vnc.html $PROJECTOR_DIR/novnc/index.html && \
#     # Tiger VNC
#     tar xf $PROJECTOR_DIR/tigervnc-1.11.0.x86_64.tar.gz --strip 1 -C / && \
#     # Install websockify
#     mkdir -p $PROJECTOR_DIR/novnc/utils/websockify && \
#     # Before updating the noVNC version, we need to make sure that our monkey patching scripts still work!!
#     tar xf $PROJECTOR_DIR/noVNC-1.2.0.tar.gz --strip 1 -C $PROJECTOR_DIR/novnc && \
#     tar xf $PROJECTOR_DIR/websockify-0.9.0.tar.gz --strip 1 -C $PROJECTOR_DIR/novnc/utils/websockify && \
#     chmod +x -v $PROJECTOR_DIR/novnc/utils/*.sh && \
#     # create user vnc directory
#     mkdir -p /home/$PROJECTOR_USER_NAME/.vnc 



# # Install xfce4 & gui tools
# RUN \
#     apt-get update && \
#     apt-get install -y --no-install-recommends software-properties-common && \
#     # Use staging channel to get newest xfce4 version (4.16)
#     add-apt-repository -y ppa:xubuntu-dev/staging && \
#     apt-get update && \
#     apt-get install -y --no-install-recommends xfce4 && \
#     apt-get install -y --no-install-recommends gconf2 && \
#     apt-get install -y --no-install-recommends xfce4-terminal && \
#     apt-get install -y --no-install-recommends xfce4-clipman && \
#     apt-get install -y --no-install-recommends xterm && \
#     apt-get install -y --no-install-recommends --allow-unauthenticated xfce4-taskmanager  && \
#     # Install dependencies to enable vncserver
#     apt-get install -y --no-install-recommends xauth xinit dbus-x11 && \
#     # Install gdebi deb installer
#     apt-get install -y --no-install-recommends gdebi && \
#     # Search for files
#     apt-get install -y --no-install-recommends catfish && \
#     #apt-get install -y --no-install-recommends font-manager && \
#     # vs support for thunar
#     apt-get install -y thunar-vcs-plugin && \
#     # Disk Usage Visualizer
#     apt-get install -y --no-install-recommends baobab && \
#     # Lightweight text editor
#     apt-get install -y --no-install-recommends mousepad && \
#     apt-get install -y --no-install-recommends vim && \
#     # Process monitoring
#     apt-get install -y --no-install-recommends htop && \
#     # Install Archive/Compression Tools: https://wiki.ubuntuusers.de/Archivmanager/
#     apt-get install -y p7zip p7zip-rar && \
#     apt-get install -y --no-install-recommends thunar-archive-plugin && \
#     apt-get install -y xarchiver && \
#     # DB Utils
#     apt-get install -y --no-install-recommends sqlitebrowser && \
#     # Install nautilus and support for sftp mounting
#     apt-get install -y --no-install-recommends nautilus gvfs-backends && \
#     # Install gigolo - Access remote systems
#     apt-get install -y --no-install-recommends gigolo gvfs-bin && \
#     # xfce systemload panel plugin - needs to be activated
#     # apt-get install -y --no-install-recommends xfce4-systemload-plugin && \
#     # Leightweight ftp client that supports sftp, http, ...
#     apt-get install -y --no-install-recommends gftp && \
#     apt-get install -y --no-install-recommends firefox && \
#     # Cleanup
#     apt-get purge -y pm-utils xscreensaver* && \
#     # Large package: gnome-user-guide 50MB app-install-data 50MB
#     apt-get remove -y app-install-data gnome-user-guide && \   
#     apt-get clean && \
#     apt-get autoremove -y && \
#     rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*
    

# Install others

RUN \
    apt-get update && \
    apt-get install -y nginx nginx-common && \
    mkdir -p /var/log/nginx/ && \
    touch /var/log/nginx/upstream.log && \
    # Cleanup
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

RUN \
    apt-get update && \
    apt-get install -y locales gosu && \
    sed -i -e 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    dpkg-reconfigure --frontend=noninteractive locales  &&\
    # Cleanup
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# RUN \
#     apt-get update && \
#     apt-get install -y fcitx && \
#     apt-get install -y fcitx-googlepinyin fcitx-pinyin fcitx-sunpinyin && \
#     apt-get install -y libgsettings-qt-dev qt5-default libqt5qml5 libxss-dev && \
#     # Cleanup
#     apt-get clean && \
#     apt-get autoremove -y && \
#     rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# RUN im-config -n fcitx

# # ros2
# ARG ROS_DISTRO=galactic
# ARG INSTALL_PACKAGE=desktop

# RUN apt-get update -q && \
#     apt-get install -y curl gnupg2 lsb-release && \
#     curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
#     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
#     apt-get update -q && \
#     apt-get install -y ros-${ROS_DISTRO}-${INSTALL_PACKAGE} \
#     python3-argcomplete \
#     python3-colcon-common-extensions \
#     python3-rosdep python3-vcstool \
#     ros-${ROS_DISTRO}-gazebo-ros-pkgs && \
#     rosdep init && \
#     # Cleanup
#     apt-get clean && \
#     apt-get autoremove -y && \
#     rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# RUN gosu ide rosdep update 
    # && \
    # grep -F "source /opt/ros/${ROS_DISTRO}/setup.bash" /home/ide/.bashrc || echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/ide/.bashrc && \
    # sudo chown ide:ide /home/ide/.bashrc

# temporally fix to enable resize uri
# https://github.com/fcwu/docker-ubuntu-vnc-desktop/pull/247
# RUN sed -i "s#location ~ .*/(api/.*|websockify) {#location ~ .*/(api/.*|websockify|resize) {#" /etc/nginx/sites-enabled/default
  
USER $PROJECTOR_USER_NAME
ENV HOME /home/$PROJECTOR_USER_NAME

# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for ide: success" && \
    # create .bashrc.d folder and source it in the bashrc
    mkdir -p /home/$PROJECTOR_USER_NAME/.bashrc.d && \
    (echo; echo "for i in \$(ls -A \$HOME/.bashrc.d/); do source \$HOME/.bashrc.d/\$i; done"; echo) >> /home/$PROJECTOR_USER_NAME/.bashrc  && \
    echo "export CUDACXX=/usr/local/cuda/bin/nvcc"  >> $HOME/.bashrc  && \
    echo "export CUDA_HOME=/usr/local/cuda"  >> $HOME/.bashrc  && \
    echo "export PATH=$PATH:\$CUDA_HOME/bin" >> $HOME/.bashrc && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$CUDA_HOME/lib64" >> $HOME/.bashrc

EXPOSE 5678

#CMD ["bash", "-c", "/run.sh"]

#USER root

#EXPOSE 8887

##CMD ["bash", "-c", "/run.sh"]

COPY gosu_entrypoint.sh /idesh/gosu_entrypoint.sh
RUN sudo chmod +x /idesh/gosu_entrypoint.sh
# RUN sudo chmod +x $PROJECTOR_DIR/start-vnc-server.sh 
RUN sudo chmod 777 /home -R
RUN sudo chown -R $USERNAME:$USERNAME /home/project
RUN sudo chmod 777 /tmp -R
RUN sudo chown -R $USERNAME:$USERNAME /tmp

COPY proxy.conf /etc/nginx/conf.d/
COPY ssl.crt $PROJECTOR_DIR/ssl.crt
COPY ssl.key $PROJECTOR_DIR/ssl.key
ENTRYPOINT ["/idesh/gosu_entrypoint.sh"]
