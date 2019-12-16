# NextflowからCWLで書かれたワークフローを呼び出す
2019/12/17

この記事は[Workflow Advent Calendar 2019](https://qiita.com/advent-calendar/2019/workflow)の17日目の記事です。

[@yuifu](https://twitter.com/yuifu) です。大学で[バイオインフォマティクスの研究室](https://sites.google.com/view/ozakilab-jp)を主宰しており、普段は転写因子やRNA結合タンパク質の結合データ、シングルセルRNA-seqデータ、空間トランスクリプトームデータの解析やそのための解析手法開発の研究をしています。

なお、この記事は[23th Workflow Meetup
](https://github.com/manabuishii/workflow-meetup/wiki/20191216)の時間内に書かれたものです。主催者や参加者の方々にこの場を借りて感謝申し上げます。

# 導入
## ワークフロー記述言語について

[研究の再現性の確保は喫緊の課題である](https://www.nature.com/news/1-500-scientists-lift-the-lid-on-reproducibility-1.19970)。研究におけるバイオインフォマティクス・データ解析の比重が増加している昨今では、バイオインフォマティクス・データ解析の再現性の確保が不可欠である。実際、バイオインフォマティクスの専門性の不足から誤った結論に至ることがある（例えば、[RNAエディティング研究](https://www.nature.com/news/rna-editing-study-under-intense-scrutiny-1.10217)、[構造生物学研究](http://science.sciencemag.org/content/314/5807/1856.full)、[進化生物学研究](https://www.pnas.org/content/113/18/5053)での論文取り下げや修正が落ちている）。


特に、NGS（ハイスループットDNAシーケンサー）データなどのバイオデータ解析は、ワークフロー（すなわち、複数のソフトウェアを順次実行する過程）で構成されている。そのため、ワークフローの正確な記述とそれに基づく実行が、データ解析の再現性確保のための技術的要件となっている。

ワークフローは素課程（ステップ）の連なりとして定義される。各ステップは入出力（ファイル）とソフトウェア実行スクリプト（ソフトウェア、バージョン、実行オプション）から構成され、ステップの間をデータが流れていくイメージである。このようなワークフローを記述するのがワークフロー記述言語（Workflow language）である。

ワークフロー記述言語には、ざっくり言うと、ドメイン固有言語（DSL）型とマークアップ言語（ML）型がある（下表）。

|   |  DSL型 | ML型  |
|---|---|---|
|  長所 |  柔軟な記述が可能（例：ループ、条件分岐） |  機械可読、他の記述形式との変換が用意 |
| 短所  | 独自の文法を習得する必要がある  | 複雑な処理（〜ループとか）を書くのが苦手  |
| 向いてそうな用途 | 人数が限られたチーム内  |  大人数での開発 |
|  例 | Nextflow、Snakemake  |  Galaxy、Common Workflow Language (CWL) |

## Common Workflow Language (CWL)について
ワークフロー言語はすでに数百あり、それらの間での互換性を確保しようとすると、全対全の組み合わせについて変換を書かねばならず大変である。それらのワークフロー言語の間でパイプラインの互換性を担保する仕組みとして[Common Workflow Language (CWL)](https://www.commonwl.org/)が開発されている。

CWLはML型のワークフロー記述言語であり、パイプラインを記述する様々なシステム間でパイプラインを共有するための交換言語として開発された。現在、SnakemakeやGalaxy など[多くのワークフロー記述言語・実行系に対応している](https://www.nature.com/articles/d41586-019-02619-z)。

## Nextflowについて
Nextflowは、DSL型のワークフロー記述言語＋ワークフロー実行系である。GroovyをベースとしたDSLであり、条件分岐、ループ、複雑なオプションの組み合わせ、リソース管理など柔軟な操作が可能である。Nextflowで書かれたバイオインフォマティクスパイプラインのレポジトリである[nf-core](https://nf-co.re/)などワークフローを共有するためのプラットフォームも整備されつつある。

そのようなNextflowであるが、実はCWLとの連携が困難である。実際、Nextflowは[2017年のブログポストを最後に](https://www.nextflow.io/blog/2017/nextflow-and-cwl.html)CWLと連携を諦めてしまっている。そのため、現状、NextflowはCWLの夢見るエコシステムから切り離された状態にある。


# NextflowでCWLで書かれたワークフローを呼び出す

既にCWLで書かれたワークフローがあるならば、それをNextflowのパイプラインとして取り込めれば便利である。例えば、すでにCWLで書かれたワークフローを、自分の書いているパイプラインの一部として使うことができれば、開発効率の向上が期待される。

そこで、NextflowからCWLで書かれたワークフローを呼び出すことを試みた。やり方は単純で、Nextflowの中からCWLで書かれたパイプラインを実行するだけである。

## cwltool

まず、CWLの実行系を選ぶ。CWLで書かれたパイプラインを実行する仕組みは色々あるが、ここでは [cwltool](https://github.com/common-workflow-language/cwltool) を用いた。cwltoolでは以下のような記法でCWLで書かれたワークフローを実行できる。

```
cwltool [tool-or-workflow-description] [input-job-settings]
```

### cwltool のDockerイメージ

[cwltoolの公式Dockerコンテナ](https://hub.docker.com/r/commonworkflowlanguage/cwltool/)がDocker Hubにあるが、これをそのまま使うとうまくいかない。それは、Nextflowはbashを前提としているが、このイメージにはbashがインストールされていないためである。
そこでまず、まず、[cwltoolに加えてbashもインストールしたのDockerイメージ yuifu/cwltool-with-bash](https://hub.docker.com/r/yuifu/cwltool-with-bash)を作成した。

なお、cwltool特有の事情により、このDockerイメージを実行する際には、以下のような[実行オプションが必要となる](https://hub.docker.com/r/commonworkflowlanguage/cwltool/)。

```
docker -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -v "$PWD":"$PWD" -w="$PWD" commonworkflowlanguage/cwltool "$@"
```

## 例：SRAからFASTQファイルを落とし、kallistoで遺伝子発現量を定量する

以下のようなワークフローを書くとする。

1. リストに書かれたRun IDのSRAファイル（`.sra`）をダウンロードする
2. [pfastq-dump](https://github.com/inutano/pfastq-dump)でSRAファイルをFASTQファイル（`.fastq`）に変換する
3. [kallisto](https://pachterlab.github.io/kallisto/) で遺伝子発現量を定量する

このうち、1〜２については、既に[pitagora-network/pitagora-cwl](https://github.com/pitagora-network/pitagora-cwl)から[SRA（Short Read Archive）からSRAファイルをダウンロードしてFASTQファイルに変換するCWLワークフロー](https://github.com/pitagora-network/pitagora-cwl/tree/master/workflows/download-fastq)が公開されている。ので、これを使いたい。

### CWLで書かれたワークフローをNextflowから呼び出す

Nextflowでは、ワークフローの各ステップはProcessと呼ばれ、書き方でProcessを定義する。

```
process プロセス名 {
    // 色々オプションを書く

    input:
    // 入力を書く

    output:
    // 出力について書く

    script:
    // 実行スクリプトを書く（シェルスクリプトなど）
}
```


以下のコマンドで、Run IDが`SRR1274307`である`.sra`ファイルをダウンロードし、pfastq-dumpでFASTQファイルに変換できる。

```
$ cwltool "https://raw.githubusercontent.com/pitagora-network/pitagora-cwl/master/workflows/download-fastq/download-fastq.cwl" --run_ids "SRR1274307"
```

これをNextflowで実行するには、以下のように書けばよい：

```
process download_fastq {
    publishDir "download_fastq"

    container "yuifu/cwltool-with-bash:1.0.20180809224403"
    containerOptions = '-v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -v "$PWD":"$PWD" -w="$PWD"'

    input:
    set sample_id, run_id from run_ids

    output:
    set sample_id, file("${sample_id}.fastq.gz") into fastq_files

    script:
    """
    cwltool --debug "https://raw.githubusercontent.com/pitagora-network/pitagora-cwl/master/workflows/download-fastq/download-fastq.cwl" --run_ids ${run_id}
    mv *.fastq.gz ${sample_id}.fastq.gz
    """
}
```

Nextflow全体ではこうなる：

```
#!/usr/bin/env nextflow

/* 
 * nextflow run download_sra_and_kallisto.nf -c job.config -with-report -resume
 */

Channel
    .fromPath(params.list_run_ids)
    .splitCsv(header: true, sep: "\t")
    .map{ 
        [it.Sample_ID, it.Run_ID]
    }
    .into{run_ids; run_ids_}

run_ids_.println()

process download_fastq {
    publishDir "download_fastq"

    container "yuifu/cwltool-with-bash:1.0.20180809224403"
    containerOptions = '-v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -v "$PWD":"$PWD" -w="$PWD"'

    input:
    set sample_id, run_id from run_ids

    output:
    set sample_id, file("${sample_id}.fastq.gz") into fastq_files

    script:
    """
    cwltool --debug "https://raw.githubusercontent.com/pitagora-network/pitagora-cwl/master/workflows/download-fastq/download-fastq.cwl" --run_ids ${run_id}
    mv *.fastq.gz ${sample_id}.fastq.gz
    """
}

process kallisto_se {
    publishDir "kallisto/$sample_id", mode: 'move'

    container "quay.io/biocontainers/kallisto:0.44.0--h7d86c95_2"

    input:
    set sample_id, file(fastq) from fastq_files
    path kallisto_index from params.path_kallisto_index

    output:
    file "$sample_id/*" into kallisto_results

    script:
    """
    kallisto quant -i ${kallisto_index} -o ${sample_id} --single -l 200 -s 20 $fastq
    """
}
```

Nextflowでは設定をconfigに書くこともできる`job.config`:
```
params{
	list_run_ids = "list_run_ids.csv"

    path_kallisto_index = "${HOME}/homo_sapiens/transcriptome.idx"
}

docker {
    enabled = true
}
```

### 実行してみる

実行環境は以下の通り：
- MacBook Pro (13-inch, 2017, Four Thunderbolt 3 Ports)
- 3.5 GHz Intel Core i7
- 16 GB 2133 MHz LPDDR3
- 備考：Kallistoは、。MacのDocker Desktopでは、デフォルトでメモリが2 GBに制限されているので、4 GBに変えておく（デフォルトのままだと、Kallistoが落ちる。`homo_sapiens/transcriptome.idx`は2.3 GBあるため？）。

あらかじめ、以下のコマンドでkallistoのヒトトランスクリプトームのインデックスをダウンロードする：

```
$ cd
$ wget https://github.com/pachterlab/kallisto-transcriptome-indices/releases/download/ensembl-96/homo_sapiens.tar.gz
$ tar xvzf homo_sapiens.tar.gz
```

以下のコマンドで、nextflowのワークフローを実行する：

```
$ nextflow run download_sra_and_kallisto.nf -c job.config -with-report -resume
N E X T F L O W  ~  version 19.10.0
Launching `download_sra_and_kallisto.nf` [friendly_wing] - revision: a2701e2878
[hNSC_001, SRR8452726]
[hNSC_002, SRR8452727]
executor >  local (2)
[98/a2fdcd] process > download_fastq (1) [100%] 2 of 2, cached: 2 ✔
[3d/63b95f] process > kallisto_se (2)    [100%] 2 of 2 ✔
Completed at: 16-Dec-2019 16:56:05
Duration    : 4m 7s
CPU hours   : 0.1 (0.1% cached)
Succeeded   : 2
Cached      : 2
````

うまく実行されると以下のようなファイルが`kallisto/`ディレクトリに作られる：

```
$ tree kallisto/
kallisto/
├── hNSC_001
│   └── hNSC_001
│       ├── abundance.h5
│       ├── abundance.tsv
│       └── run_info.json
└── hNSC_002
    └── hNSC_002
        ├── abundance.h5
        ├── abundance.tsv
        └── run_info.json

4 directories, 6 files
```




# まとめ

CWLで書かれたワークフローをNextflowから半ば無理やり呼び出すことができた。
Nextflowを使っている人が、サクッとCWLで書かれたワークフローを使うのに便利かもしれない。

問題