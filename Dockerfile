FROM library/ubuntu:xenial
MAINTAINER Antoine Webanck <antoine.webanck@gmail.com>

# Creating the wine user and setting up dedicated non-root environment: replace 1001 by your user id (id -u) for X sharing.
RUN useradd -u 1001 -d /home/wine -m -s /bin/bash wine
ENV HOME /home/wine
WORKDIR /home/wine

# Adding the helper script and an alias to launch the steam to be installed.
COPY finalize_installation.sh /home/wine/.finalize_installation.sh
RUN chown wine:wine /home/wine/.finalize_installation.sh && \
	chmod o+x /home/wine/.finalize_installation.sh && \
	su -p -l wine -c "echo 'alias finalize_installation=\"bash /home/wine/.finalize_installation.sh\"' >> /home/wine/.bashrc" && \
	su -p -l wine -c "echo 'alias steam=\"wine /home/wine/.wine/drive_c/Program\ Files/Steam/Steam.exe -no-cef-sandbox > /dev/null \"' >> /home/wine/.bashrc"

# Setting up the wineprefix to force 32 bit architecture.
ENV WINEPREFIX /home/wine/.wine
ENV WINEARCH win32

# Disabling warning messages from wine, comment for debug purpose.
ENV WINEDEBUG -all

# Adding the link to the pulseaudio server for the client to find it.
ENV PULSE_SERVER unix:/run/user/1001/pulse/native

#########################START  INSTALLATIONS##########################

# We don't want any interaction from package installation during the docker image building.
ENV DEBIAN_FRONTEND noninteractive


# We want the 32 bits version of wine allowing winetricks.
RUN	dpkg --add-architecture i386 && \

# Updating and upgrading a bit.
	apt-get update && \
	apt-get upgrade -y && \

# We need software-properties-common to add ppas and wget and apt-transport-https to add repositories and their keys.
	apt-get install -y --no-install-recommends software-properties-common apt-transport-https wget && \

# Adding required ppas: graphics drivers and wine.
	add-apt-repository ppa:graphics-drivers/ppa && \
	wget -nc https://dl.winehq.org/wine-builds/Release.key && apt-key add Release.key && add-apt-repository https://dl.winehq.org/wine-builds/ubuntu/ && \
	apt-get update && \

# Installation of graphics driver.
	apt-get install -y --no-install-recommends initramfs-tools nvidia-384 && \

# Installation of wine, winetricks and its utilities and temporary xvfb to install latest winetricks and its tricks during docker build.
	apt-get install -y --no-install-recommends winehq-stable cabextract unzip p7zip zenity && \
	wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && chmod +x winetricks && mv winetricks /usr/local/bin && \
# Installation of winbind to stop ntlm error messages.
	apt-get install -y --no-install-recommends winbind && \
# Installation of p11 to stop p11 kit error messages.
	apt-get install -y --no-install-recommends p11-kit-modules:i386 libp11-kit-gnome-keyring:i386 && \
# Installation of pulseaudio support for wine sound.
	apt-get install -y --no-install-recommends pulseaudio:i386 && \
	sed -i "s/; enable-shm = yes/enable-shm = no/g" /etc/pulse/daemon.conf && \
	sed -i "s/; enable-shm = yes/enable-shm = no/g" /etc/pulse/client.conf && \

# Installation of winetricks' tricks as wine user, comment if not needed.
	su -p -l wine -c 'winecfg && wineserver --wait' && \
	su -p -l wine -c 'winetricks -q winxp && wineserver --wait' && \
	su -p -l wine -c 'winetricks -q sound=pulse && wineserver --wait' && \
	su -p -l wine -c 'winetricks -q corefonts && wineserver --wait' && \
	su -p -l wine -c 'winetricks -q dotnet40 && wineserver --wait' && \
	su -p -l wine -c 'winetricks -q xna40 && wineserver --wait' && \
	su -p -l wine -c 'winetricks -q d3dx9 && wineserver --wait' && \
	su -p -l wine -c 'winetricks -q directplay && wineserver --wait' && \

# Cleaning up.
	apt-get autoremove -y --purge software-properties-common && \
	apt-get autoremove -y --purge && \
	apt-get clean -y && \
	rm -rf /home/wine/.cache && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#########################END OF INSTALLATIONS##########################

# Launching the shell by default as wine user.
USER wine
CMD /bin/bash
