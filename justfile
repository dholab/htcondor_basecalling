@default:
    just --list

alias readme := make-readme
alias zip := compress_html
alias doc := docs
alias container_prep := docker
alias doit := all

render:
    quarto render docs/index.qmd

make-readme:
    @mv docs/index.md ./README.md

compress_html:
    @gzip -f docs/index.html

qmd: render

docs: render make-readme compress_html

docker-build:
    docker build -t nrminor/htcondor-basecall:v0.1.0 .

docker-push:
    docker push nrminor/htcondor-basecall:v0.1.0

docker: docker-build docker-push

all: docs docker