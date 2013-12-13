####
## Install libraries (run once)
#install.packages(c('plyr','foreign','doSNOW','foreach'))

####
## Load libraries
library(plyr)    # data frame manipulation
library(foreign) # reading shapefile *.dbf
library(doSNOW)  # parallel processing
library(foreach)

####
## Start cluster (set # of CPUs)
cl = makeCluster(6, type = "SOCK")
registerDoSNOW(cl)
## Stop cluster
#stopCluster(cl)


####
## FUNCTIONS

## Load Template
# see: http://fallingfruit.org/locations/import
load.template = function() {
  fields = c('Type','Type.Other','Description','Lat','Lng','Address','Season.Start','Season.Stop','No.Season','Access','Unverified','Yield.Rating','Quality.Rating','Author','Photo.URL')
  template = data.frame(t(rep(NA,length(fields))))
  names(template) = fields
  template
}

## Load Key
# Builds the standard format used for filtering databases of species names. Expects a UTF-8 tab delimited file that includes the following fields...
# Common : Common name of the plant, must be the same as Falling Fruit type
# Scientific : Scientific name of the plant, as Genus or Genus species
# Rating : -1 = avoid, 1 = include, 2 = maybe include
load.key = function(keyfile = NULL) {
  if (is.null(keyfile)) {
    keyfile = '~/sites/falling-fruit/data/species_key.tab'
  }
	key = read.table(keyfile, sep = "\t", stringsAsFactors=F, header=T, encoding="UTF-8")
	key$Common = gsub("  "," ",key$Common)
	key$Common = gsub("[ ]+$|^[ ]+","",key$Common)
	key$Common = tolower(key$Common)
	key$Common = gsub("^([a-zA-Z])","\\U\\1",key$Common,perl=T)
	key$Scientific = gsub("  "," ",key$Scientific)
	key$Scientific = gsub("[ ]+$|^[ ]+","",key$Scientific)
	temp = strsplit(key$Scientific," ")
	for (i in 1:length(temp)) {
		key$Genus[i] = temp[[i]][1]
		if (length(temp[[i]]) > 1) {
			key$Species[i] = temp[[i]][2]
		} else {
			key$Species[i] = ""
		}
	}
	key$ScientificSP[key$Species == ""] = paste(key$Scientific[key$Species == ""],"sp",sep=" ")
	key$ScientificSP[key$Species != ""] = key$Scientific[key$Species != ""]
	key
}

## Capitalize first letter of each word
capwords = function(s, strict = FALSE) {
	cap = function(s) {
		paste(toupper(substring(s,1,1)), {s = substring(s,2); if(strict) tolower(s) else s}, sep = "", collapse = " " )
	}
	s = sapply(strsplit(s, split = " "), cap, USE.NAMES = !is.null(names(s)))
	gsub("([/\\(])([a-z])", "\\1\\U\\2", s, perl=T)	# Capitalize letter proceeding (,/
	gsub("'([a-z])([a-z])", "'\\U\\1\\L\\2", s, perl=T)	# Capitalize letter proceeding '
}

## Format Scientific
format.field = function(x,types='') {
	x = gsub("^[ ]+|[ ]+$","",x)	# remove trailing spaces
	x = gsub("[ ]+"," ",x)	# remove duplicate spaces
	x = gsub("`|\\\"","'",x)	# quotes -> '
	x = gsub("[ ]*\\([ ]*\\)","",x)	# empty parenthesis
	x = gsub("\\.[ ]*\\.",".",x)	# trailing period (occurs when pasting empty strings)
	x = gsub("^[ ]*\\.[ ]*","",x)	# leading period
	if ('address' %in% types) {
		x = capwords(x,strict=T)	# uppercase each word
		x = gsub("\\.","",x)	# remove periods
		x = gsub("Se( |$)","SE\\1",x)	# capitalize SE,SW,NE,NW
		x = gsub("Sw( |$)","SW\\1",x)
		x = gsub("Ne( |$)","NE\\1",x)
		x = gsub("Nw( |$)","NW\\1",x)
		x = gsub("Mc([a-z])","Mc\\U\\1",x,perl=T)	# restore McCaps
		x = gsub("Av( |$)","Ave\\1",x)	# Av -> Ave
	}
	if ('species' %in% types) {
		x = gsub("\\.","",x)	# remove periods
		x = gsub("species|spp( |$)|ssp( |$)|sp( |$)","sp\\1",x,ignore.case=T) # species -> sp
		x = gsub("(^[a-zA-Z]+$)","\\1 sp",x) # Genus -> add sp
		x = gsub("^([a-z])","\\U\\1",x,perl=T)
	}
	return(x)
}

####
## Filter
filter.data = function(data, genus = TRUE) {

	# load key
	key = load.key()
	
	# pre-filter (genus)
	if (genus) {
		ind = grepl(paste(unique(key$Genus[key$Rating > 0]),collapse=" |^"),data$Scientific,ignore.case=T)
		data = data[ind,]
	}
		
	# filter (species)
	data$Type = NA
	data$Rating = NA
	CPU = 6
	blocks = CPU
	N = nrow(data)
	starts = seq(1,N,round(N/CPU))
	stops = c(starts[-1]-1,N)
	data = foreach(i=1:length(starts),.combine = rbind) %dopar% { 
		cdata = data[starts[i]:stops[i],]
		cropind = rep(TRUE,nrow(cdata))
		for (i in 1:nrow(key)) {
			ind = grepl(key$ScientificSP[i],cdata$Scientific[cropind],ignore.case=T)
			if (sum(ind) > 0) {
				cdata$Type[cropind][ind] = key$Common[i]
				cdata$Rating[cropind][ind] = key$Rating[i]
				cropind[cropind][ind] = FALSE
			}
		}
		cdata
	}
}

####
## Flatten
# requires: Lat Lng | Address, Type, (Description), (Notes), (Unverified), (Author)
flatten.data = function(data, notesep = " @ ") {
	
	# dpply parameters
	parallel = FALSE
	if (parallel) {
		progress = "none"
	} else {
		progress = "text"
	}
	
	# add missing fields
	reqfields = c("Description","Notes","Unverified","Author","Access")
	misfields = setdiff(reqfields, names(data))
	data[misfields] = NA
	
	# group by type	
	typefields = intersect(names(data), c("Type","Description"))
	if (!("Type" %in% names(data))) {
		stop("Missing type!")
	}
	
	# group by position
	posfields = intersect(names(data), c("Lat","Lng","Address"))
	posfields = posfields[colSums(is.na(data[posfields])) < nrow(data)]
	if (length(posfields) == 1 && posfields != "Address") {
		stop(paste("Location incorrectly defined: ",paste(posfields,collapse=", ")))
	} else if (length(posfields) == 2 & !all(posfields %in% c("Lat","Lng"))) {
		stop(paste("Location incorrectly defined: ",paste(posfields,collapse=", ")))
	} else if (length(posfields) > 2) {
		stop(paste("Location over-defined: ",paste(posfields,collapse=", ")))
	} else if (length(posfields) == 0) {
	  stop("No location fields (either Lat & Lng, or Address) found.")
	}
	
	# keep only required fields (since processing singles separately)
	data = data[unique(c(posfields,typefields,reqfields))]
	
	# find overlapping
	fdind = duplicated(data[,posfields],fromLast= F)
	ldind = duplicated(data[,posfields],fromLast= T)
	dind = fdind | ldind

	# flatten overlapping data
	if (sum(dind) > 0) {
		ddata = data[dind,]
		ddata = ddply(ddata, c(posfields,typefields), summarize, Description = paste("[",length(Type),"x] ",Description[1],sep=""), Notes = unique.na(Notes), Unverified = max(Unverified,na.rm=T), Access = unique.na(Access), Author = Author[1], .progress = progress, .parallel = parallel)
		ddata = ddply(ddata, posfields, summarize, Type = paste(unique(Type), collapse=","), Description = paste(Description, collapse=", "), Notes = unique.na(Notes), Unverified = max(Unverified,na.rm=T), Access = unique.na(Access), Author = Author[1], .progress = progress, .parallel = parallel)
	}
	
	# Recombine
	if (sum(dind) != nrow(data)) {
    data = data[!dind,]
    data$Description = paste("[1x] ",data$Description,sep="") # COMMENT OUT to remove "[1x]"
    if (sum(dind) > 0) {
      data = rbind(ddata, data)
    }
  } else {
    data = ddata
  }
  
	# append surviving notes to item description
	hasdesc = !is.na(data$Description)
	hasnote = !is.na(data$Notes)
	data$Description[hasdesc & hasnote] = paste(data$Description[hasdesc & hasnote], notesep, data$Notes[hasdesc & hasnote], sep="")
	data$Description[!hasdesc & hasnote] = data$Notes[!hasdesc & hasnote]
	#data$Description = gsub(paste("[ ]+",notesep,"[ ]+$|^[ ]+|[ ]+$",sep=""),"",data$Description)
	#data$Description = gsub(paste("[ ]{2,}",sep=" "),"",data$Description)
	
	# check results
	N = nrow(data)
	Npos = nrow(unique(data[posfields]))
	if (N != Npos) {
		warning(paste(N-Npos,"placemarks still overlap!"))
	}
	
	# return result
	return(data)
}

## Return unique, or NA
# Helper function for flatten.data()
unique.na = function(x) {
	ux = unique(x)
	if (length(ux) == 1) {
		return(ux)
	} else {
		return(NA)
	}
}

####
## Export
export.data = function(dt, file, dropfields = T) {
	template = load.template()
  extrafields = setdiff(names(dt), names(template)) 
	addfields = setdiff(names(template), names(dt))
	dt = cbind(dt,template[addfields])
	dt = dt[c(names(template), extrafields)]
	if (dropfields) {
	  dt = dt[,!(names(dt) %in% extrafields)]
	}
	names(dt) = gsub("\\."," ",names(dt))
	write.csv(dt, gsub('\\.csv|\\.dbf|\\.shp','-FINAL.csv',file), na= "", row.names = F)
}

##########
## Quality Control

## Check for overlapping placemarks
# files = dir('.','*-FINAL\\.csv',recursive=T)
# for (file in files) {
	# df = read.csv(file,stringsAsFactors = F)
	# print(file)
	# if (is.na(df$Lat[1]) | df$Lat[1] == "") {
		# print(sum(duplicated(df[c("Address")])))
	# } else {
		# print(sum(duplicated(df[c("Lat","Lng")])))
	# }
# }