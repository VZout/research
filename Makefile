all: paper

paper:
	@pandoc --filter pandoc-crossref --filter pandoc-citeproc -N \
	-V linkcolor:blue \
    -V geometry:a4paper \
	-V geometry:a4paper \
    -V geometry:margin=2cm \
	--bibliography=paper.bib --highlight-style tango --variable classoption=twocolumn --variable papersize=a4paper -s paper.md -o paper.pdf -H header.tex

clean:
	rm paper.pdf

.PHONY: all clean paper
