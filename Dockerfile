FROM mambaorg/micromamba:git-8219a05-focal-cuda-12.5.0

# install anything that's available from conda registries
COPY --chown=$MAMBA_USER:$MAMBA_USER env.yaml /tmp/env.yaml
RUN micromamba install -y -n base -f /tmp/env.yaml && \
    micromamba clean --all --yes && \
    micromamba shell init --shell bash --root-prefix=~/micromamba

# put conda stuff on the path
ENV PATH=$PATH:/opt/conda/bin

# pull the latest dorado executable
RUN cd ~ && \
    wget --quiet https://cdn.oxfordnanoportal.com/software/analysis/dorado-0.7.1-linux-x64.tar.gz && \
    tar -xvf dorado-0.7.1-linux-x64.tar.gz && \
    rm -rf dorado-0.7.1-linux-x64.tar.gz

# add the dorado files to $PATH
ENV PATH=$PATH:~/dorado-0.7.1-linux-x64/bin:~/dorado-0.7.1-linux-x64/lib:~/dorado-0.7.1-linux-x64

# predownload dorado models so that dorado can basecall offline
RUN cd ~ && dorado download
