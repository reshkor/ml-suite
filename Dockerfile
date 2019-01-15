FROM ubuntu:xenial

RUN apt-get update && apt-get -y install redir curl bzip2 git iputils-ping libgl1 && apt-get clean
RUN curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/nimbix/image-common/master/install-nimbix.sh | bash

# JARVICE doesn't support straight Debian containers, so install Anaconda 2
# into this Ubuntu one rather than use FROM continuumio/anaconda above
WORKDIR /tmp
ENV PATH=/opt/anaconda2/bin:${PATH}
RUN curl -O https://repo.anaconda.com/archive/Anaconda2-5.1.0-Linux-x86_64.sh && bash ./Anaconda2-5.1.0-Linux-x86_64.sh -b -p /opt/anaconda2 && rm -f Anaconda2-5.1.0-Linux-x86_64.sh && conda update -n base conda && conda clean -y --all

# helper in case someone runs sudo conda
COPY JARVICE/conda /usr/bin/conda
RUN ln -s /opt/anaconda2/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# deploy the Anaconda EULA so that JARVICE prompts the end user to accept it,
# since we accepted it in batch above
RUN mkdir -p /etc/NAE && cp -f /opt/anaconda2/LICENSE.txt /etc/NAE/license.txt

# Create the ml-suite Anaconda Virtual Environment...
# see: https://github.com/Xilinx/ml-suite/blob/v1.0-ea/docs/tutorials/start-anaconda.md
#RUN conda create -y --name ml-suite python=2.7 jupyter caffe pydot pydot-ng graphviz -c conda-forge && conda clean -y --all
RUN conda create --name ml-suite python=2.7 numpy=1.14.5 x264=20131218 caffe pydot pydot-ng graphviz keras scikit-learn tqdm -c conda-forge

# Deploy this repository into the container
COPY --chown=nimbix:nimbix . /usr/src/ml-suite/

# install Git LFS
#RUN apt-get update && apt-get -y install software-properties-common && apt-add-repository -y ppa:git-core/ppa && curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && apt-get install git-lfs && apt-get clean && git lfs install


# clone ml-suite from Xilinx to /usr/src, then link it into $HOME in skep
#WORKDIR /usr/src
#ENV XILINX_ML_SUITE_BRANCH master
#ENV XILINX_ML_SUITE_CLONE_TIMESTAMP "Tue Jul 24 14:37:45 UTC 2018"
#RUN git clone -b ${XILINX_ML_SUITE_BRANCH} https://github.com/Xilinx/ml-suite.git && cd ml-suite && git lfs install --local && make -C apps/yolo/nms && cd .. && chown -R nimbix:nimbix ml-suite
RUN ln -s /usr/src/ml-suite /etc/skel/ml-suite
#WORKDIR /data

# Fix up - temporarily link in anaconda2 so we don't have to modify the script
RUN ln -s /opt/anaconda2 ~/anaconda2 && bash /etc/skel/ml-suite/fix_caffe_opencv_symlink.sh && rm -f ~/anaconda2

# motd and AppDef, URL override, and launcher for notebooks
COPY JARVICE/motd /etc/motd
COPY JARVICE/AppDef.json /etc/NAE/AppDef.json
COPY JARVICE/url.txt /etc/NAE/url.txt
COPY JARVICE/ml-notebooks /usr/local/bin/ml-notebooks
RUN curl --fail -X POST -d @/etc/NAE/AppDef.json https://api.jarvice.com/jarvice/validate
