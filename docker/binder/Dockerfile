FROM shashankpv/plutojl:multistage

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

USER root
RUN apt-get update \
    && apt-get -y install --no-install-recommends python3-pip \
    && pip3 install -vU setuptools \
    && pip3 install jupyter \
    && pip3 install jupyter-server-proxy

RUN usermod -l ${NB_USER} pluto
COPY . ${HOME}
RUN chown -R ${NB_UID} ${HOME}

USER ${NB_USER}
WORKDIR ${HOME}

RUN pip3 install .
EXPOSE 8080

CMD [ "ls" ]
