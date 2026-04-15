# Jmorphy2

Java port of [pymorphy2](https://github.com/kmike/pymorphy2) — morphological analyzer for Russian and Ukrainian.

## Build

```sh
./gradlew build
```

## Elasticsearch plugin

### Building

Default Elasticsearch version is defined in `es.version` (currently `8.19.14`).

Build against the default version:

```sh
./gradlew :jmorphy2-elasticsearch:assemble
```

Build against a specific Elasticsearch version:

```sh
./gradlew :jmorphy2-elasticsearch:assemble -PesVersion=8.19.14
```

Supported Elasticsearch versions: `8.6.x`–`8.19.x`.

Artifacts are produced in `jmorphy2-elasticsearch/build/distributions/`:
- `analysis-jmorphy2-<libVersion>-es<esVersion>.zip` — plugin archive
- `elasticsearch-analysis-jmorphy2-plugin_<libVersion>~es<esVersion>_all.deb` — debian package

### Installation

Install the assembled zip:

```sh
export es_home=/usr/share/elasticsearch
sudo ${es_home}/bin/elasticsearch-plugin install \
  "file:$(pwd)/jmorphy2-elasticsearch/build/distributions/analysis-jmorphy2-0.2.4-es8.19.14.zip"
```

Or run Elasticsearch with the locally-built plugin inside a container
(assemble first, the Dockerfile picks up the zip from `jmorphy2-elasticsearch/build/distributions/`):

```sh
./gradlew :jmorphy2-elasticsearch:assemble
podman build -t elasticsearch-jmorphy2 -f Dockerfile.elasticsearch .
podman run --rm -p 9200:9200 \
  -e "ES_JAVA_OPTS=-Xmx1g" -e "discovery.type=single-node" \
  elasticsearch-jmorphy2
```

### Smoke test

Create an index with the analyzer and check tokenization:

```sh
curl -X PUT -H 'Content-Type: application/yaml' 'localhost:9200/test_index' -d '---
settings:
  index:
    analysis:
      filter:
        delimiter:
          type: word_delimiter
          preserve_original: true
        jmorphy2_russian:
          type: jmorphy2_stemmer
          name: ru
        jmorphy2_ukrainian:
          type: jmorphy2_stemmer
          name: uk
      analyzer:
        text_ru:
          tokenizer: standard
          filter:
          - delimiter
          - lowercase
          - jmorphy2_russian
        text_uk:
          tokenizer: standard
          filter:
          - delimiter
          - lowercase
          - jmorphy2_ukrainian
'

curl -X GET -H 'Content-Type: application/yaml' 'localhost:9200/test_index/_analyze' -d '---
analyzer: text_ru
text: Привет, лошарики!
'

curl -X GET -H 'Content-Type: application/yaml' 'localhost:9200/test_index/_analyze' -d '---
analyzer: text_uk
text: Пригоди Котигорошка
'
```
