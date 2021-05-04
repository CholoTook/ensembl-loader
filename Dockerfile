FROM alpine

RUN apk add bash
RUN apk add mysql-client

WORKDIR /Ensembl

COPY load_ensembl.bash .

CMD ["bash", "load_ensembl.bash"]

