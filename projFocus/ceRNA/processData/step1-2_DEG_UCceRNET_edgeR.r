#!/usr/bin/Rscript
#Author: Jing He
#Date:24 Oct,2013 
#Last Updated:
#COMMENTS: need edgeR installed; 
#input: <string:path you wnat your results to be> 
# 		  <string:name of your design file(4 cols, tab delimite:example)
#		    <string:name of count matrix file>
# 		  <string:name of your output files>
#output: <file:pdf of 2 plots> <file: txt of differetial expresssed genes>
####TODO: need more development

sysInfo = Sys.info()
if(sysInfo['sysname']=="Darwin" ){
  source("/Volumes/ifs/home/c2b2/ac_lab/jh3283/scripts/projFocus/ceRNA/projFocusCernaFunctions.R")
  setwd("/Volumes/ifs/data/c2b2/ac_lab/jh3283/projFocus/result/02022014/expression/")
  rootd = "/Volumes/ifs/data/c2b2/ac_lab/jh3283/projFocus/"
  figd = "/Volumes/ifs/scratch/c2b2/ac_lab/jh3283/projFocus/ceRNA/report/figure/"
}else if(sysInfo['sysname']=="Linux" ){
  source("/ifs/home/c2b2/ac_lab/jh3283/scripts/projFocus/ceRNA/projFocusCernaFunctions.R")
  print("working from Linux")
  setwd("/ifs/data/c2b2/ac_lab/jh3283/projFocus/result/02022014/expression")
  rootd = "/ifs/data/c2b2/ac_lab/jh3283/projFocus/"
  figd = "/ifs/data/c2b2/ac_lab/jh3283/projFocus/report/topDown_02042014/fig/"
}

# args = getArgs()
# usage = "Usage: Rscript step1-2_DEG_UCceRNET_edgeR.r --tumor <tumor.mat file> --normal <normal.mat file>  --genelist <geneSample.list>  "
# example = "Example: /ifs/home/c2b2/ac_lab/jh3283/tools/R/R_current/bin/Rscript /ifs/home/c2b2/ac_lab/jh3283/scripts/projFocus/ceRNA/filterGrplasso.r --file grplasso_coeff --cut 0.05 --out gcGenes_GeneVarNet"
# if(length(args) < 3 || is.null(args)){
#   print(usage)
#   print(example)
#   print(args)
#   stop("Input parameter error!")
# }else{
#   print(args)
# }

setwd(system("pwd",intern=T))
# cwd         = getwd()
# tumor  = args['tumor'] 
# normal = args['normal']
# output = args['out'] 
# print(paste("current working directory:",cwd))


##-----test
cwd = getwd()
tumor  =  "brca_exp_level3_02042014.mat"
normal =  "brca_expNormal_level3_02042014.mat"
# output =  "brca_ucCeRNETCancerGeneDEG_edgeR_02042014"
output =  paste("brca_ucCeRNETCancerGeneDEG_edgeR_",substr(Sys.time(),1,10),sep="")
genelist = paste(rootd,"/result/02022014/geneSamples/cancerGenes_UCceRNETPlusNature12929.list.geneSingleStartEnd",sep="")
samplePerGenefile = paste(rootd, "/result/02022014/geneSamples/brca_geneSamplelist_combined_CG_CNVMethFree_02242014.txt",sep="")
crtDate = substr(Sys.time(),1,10)
outGeneSample = paste(samplePerGenefile,".deg_",crtDate,".txt",sep="")
outExp = paste(tumor,"_Voomed_DEGexp_",crtDate,".rda",sep="")
reportDir = paste(rootd, "/report/topDown_02042014/fig",sep="")
outputPDF = paste(reportDir,"/",output,".pdf",sep="")
##----------------------------
getData = function(file,type="T",glist){
  gene = unlist(read.table(glist)[,1])
  data = read.delim(file,header=T)
  gene = gene[ gene %in% data[,1] ]
  data = data[data[,1] %in% gene,-1]
  rownames(data)=gene
  colnames(data) = vapply(colnames(data),FUN=function(x){substr(x,start=9,stop=16)},'a')
  
  sample = colnames(data)
  design = rep(type,ncol(data))
  names(design) = sample
  return(list(data=data,design=design,gene=gene))
}

##--------#load data

dataT = getData(tumor,type='tumor',genelist)
dataN = getData(normal,type='normal',genelist)
cntSampleT = ncol(dataT$data)
cntSampleN = ncol(dataN$data)
cntGene = nrow(dataT$data)
dataMat = cbind(dataT$data,dataN$data)
gene = dataT$gene
row.names(dataMat) = gene

design = c(dataT$design,dataN$design)
condition <- factor( design )

##-------------voom transformation
require(limma)
designMat = model.matrix(~design)
dataMatVoom = voom(as.matrix(dataMat),designMat,plot=TRUE)
dataMatVoomTumor = dataMatVoom$E[,which(as.character(design)=="tumor")]
dataMatVoomNormal = dataMatVoom$E[,which(as.character(design)=="normal")]

##gene-sample infor
samplePerGene = read.table(samplePerGenefile,header=T,stringsAsFactors=F)
tarGene = unlist(samplePerGene$gene)
failGene = ""
for (ng in 1:nrow(samplePerGene)){
  samples= vapply(unlist(strsplit(samplePerGene$samples_noCNV_noMeth[ng],";")),
                  FUN=function(x){substr(x,9,16)},'a')
  temp.index = colnames(dataMatVoomTumor) %in% samples
  ttest = t.test(dataMatVoom$E[tarGene[ng],temp.index],dataMatVoomNormal[tarGene[ng],])
  ifelse (ttest$p.value > 0.05, (failGene <- c(failGene, tarGene[ng])),"PASS")
}

##---------output
idxOutGene = samplePerGene$gene %in% setdiff(tarGene,failGene)
out  =samplePerGene[idxOutGene,]
rownames(out) = samplePerGene$gene[idxOutGene]
write.table(samplePerGene[idxOutGene,],outGeneSample ,sep="\t",col.names=T,row.names=F,quote=F)

expTumor = dataMatVoomTumor[rownames(dataMatVoomTumor) %in% out$gene,]
expNormal =dataMatVoomNormal[rownames(dataMatVoomNormal) %in% out$gene,]
write.table(expTumor,paste(outExp,".mat",sep=""),sep="\t",col.names=T,row.names=T,quote=F)
save(expTumor,expNormal,out,file=outExp)
#--------------------------------------------
