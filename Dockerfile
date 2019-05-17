FROM ensemblorg/ensembl-vep:release_96.0

USER root
ENV VCF2MAF /opt/vcf2maf
RUN mkdir -p $OPT/.vep && mkdir -p $OPT/gtf && mkdir -p $VCF2MAF/data

# download GENCODE GTF & VEP cache
ADD --chown=vep:vep http://ftp.ensembl.org/pub/release-96/variation/indexed_vep_cache/homo_sapiens_vep_96_GRCh37.tar.gz $OPT/.vep/
ADD --chown=vep:vep http://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_30/GRCh37_mapping/gencode.v30lift37.annotation.gtf.gz $OPT/gtf/

# download files needed for vcf2maf
ADD --chown=vep:vep https://raw.githubusercontent.com/vanallenlab/vcf2maf/master/vcf2maf.pl $VCF2MAF/
ADD --chown=vep:vep https://raw.githubusercontent.com/vanallenlab/vcf2maf/master/data/ensg_to_entrez_id_map_ensembl96.tsv $VCF2MAF/data/
ADD --chown=vep:vep https://raw.githubusercontent.com/vanallenlab/vcf2maf/master/data/isoform_overrides_uniprot_from_biomart_91 $VCF2MAF/data/

# prepare VEP index for use
RUN cd $OPT/.vep \
    && tar xzf homo_sapiens_vep_96_GRCh37.tar.gz \
    && rm homo_sapiens_vep_96_GRCh37.tar.gz \
    && perl $OPT_SRC/ensembl-vep/convert_cache.pl -species all -version all

# prepare GTF for use (rename GENCODE chromosomes to match GRCh37, sort, index)
RUN zcat $OPT/gtf/gencode.v30lift37.annotation.gtf.gz \
    | grep -v '^#' \
    | awk 'BEGIN {FS="\t"; OFS="\t"} {if ($1 == "chrM") {$1="MT"} else {sub(/^chr/, "", $1)}; print $0}' \
    | sort -k1,1 -k2,2n -k3,3n -t$'\t' \
    | bgzip -c \
    > $OPT/gtf/gencode.v30lift37.renamed.gtf.gz \
    && tabix -p $OPT/gtf/gencode.v30lift37.renamed.gtf.gz \
    && rm $OPT/gtf/gencode.v30lift37.annotation.gtf.gz

USER vep
