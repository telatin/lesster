# This is a readme

1	CIAO	is	a	tab
2   this 	also	 A S
2			T B
## Section 1

Make dirs:

```
a temp dir (mktemp) to remove after running
```

An *output* dir to keep "./benchmark")
An **output** dir to keep "./benchmark")
An _output_ dir to keep "./benchmark")
An `output` dir to keep "./benchmark")


Steps:
1. Decompress the fastq.gz file as dsrc will not accept the gz file
2. Then benchmark compression (single threaded)
Similar to:

hyperfine "dsrc c -t1  test.fastq test.fastq.dsrc1" "bin/fastq2dsrc -t 1 test.fastq test.fastq.dsrc2" --prepare "rm test.fastq.dsrc2 || true" --write-csv {outdir}/compress_1thread.csv --write-markdown {outdoor}/compress_1thread.md

Then with 4 threads

3. Then benchmark decompression (single threaded and then 4 threads)
Similar to:
hyperfine "dsrc c -t4  test.fastq test.fastq.dsrc1" "bin/fastq2dsrc --threads=4 test.fastq test.fastq.dsrc2" --prepare "rm test.fastq.dsrc2 || true"

