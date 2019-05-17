FROM ensemblorg/ensembl-vep:release_96.0 as builder

USER root
RUN mkdir -p $OPT/.vep && mkdir -p $OPT/gtf

# add GENCODE GTF & VEP cache (from http://ftp.ensembl.org/pub/release-96/variation/indexed_vep_cache)
ADD --chown=vep:vep homo_sapiens_vep_96_GRCh37.tar.gz $OPT/.vep/
ADD --chown=vep:vep http://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_30/GRCh37_mapping/gencode.v30lift37.annotation.gtf.gz $OPT/gtf/

# prepare VEP index for use
RUN perl $OPT_SRC/ensembl-vep/convert_cache.pl --species all --version all --dir $OPT/.vep

# prepare GTF for use (rename GENCODE chromosomes to match GRCh37, sort, index)
SHELL ["/bin/bash", "-c"]
RUN zcat $OPT/gtf/gencode.v30lift37.annotation.gtf.gz \
    | grep -v '^#' \
    | awk 'BEGIN {FS="\t"; OFS="\t"} {if ($1 == "chrM") {$1="MT"} else {sub(/^chr/, "", $1)}; print $0}' \
    | sort -k1,1 -k4,4n -k5,5n -t$'\t' \
    | bgzip -c \
    > $OPT/gtf/gencode.v30lift37.renamed.gtf.gz \
    && tabix -p gff $OPT/gtf/gencode.v30lift37.renamed.gtf.gz \
    && rm $OPT/gtf/gencode.v30lift37.annotation.gtf.gz

# download files needed for vcf2maf
ENV VCF2MAF /opt/vcf2maf
ENV VCF2MAF_COMMIT 9dceb9b580a9ca0c6f6d56f4ac042d716330cbe6
RUN mkdir -p $VCF2MAF/data
ADD https://raw.githubusercontent.com/vanallenlab/vcf2maf/$VCF2MAF_COMMIT/vcf2maf.pl $VCF2MAF/
ADD https://raw.githubusercontent.com/vanallenlab/vcf2maf/$VCF2MAF_COMMIT/data/ensg_to_entrez_id_map_ensembl96.tsv $VCF2MAF/data/
ADD https://raw.githubusercontent.com/vanallenlab/vcf2maf/$VCF2MAF_COMMIT/data/isoform_overrides_uniprot_from_biomart_91 $VCF2MAF/data/


FROM quay.io/biocontainers/samtools:1.9--h8571acd_11 as samtools


FROM ensemblorg/ensembl-vep:release_96.0

USER root
ENV VCF2MAF /opt/vcf2maf
RUN mkdir -p $OPT/.vep && mkdir -p $OPT/gtf && mkdir -p $VCF2MAF/data

# copy files
COPY --chown=vep:vep --from=builder $OPT/.vep $OPT/.vep
COPY --chown=vep:vep --from=builder $OPT/gtf $OPT/gtf
COPY --chown=vep:vep --from=builder $VCF2MAF $VCF2MAF

# add samtools
COPY --chown=vep:vep --from=samtools /usr/local/bin/ /usr/local/bin/
COPY --chown=vep:vep --from=samtools /usr/local/lib/ /usr/local/lib/

USER vep
