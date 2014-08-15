####
## Install libraries (run once)
#install.packages(c('plyr','foreign','doSNOW','foreach','rgdal'))

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

####
## Load

## Load Dataset
load.data = function(file, latlng = c("Lat","Lng")) {
  
  # Read file
  if (grepl("\\.csv",file)) {
    dt = read.csv(file, stringsAsFactors=F)
  } else if (grepl("\\.dbf",file)) {
    library(foreign)
    dt = read.dbf(file,as.is=T)
  } else if (grepl("\\.shp",file)) {
    library(rgdal)
    shp = readOGR(file, layer = ogrListLayers(file)[1])
    shp = spTransform(shp, CRS("+proj=longlat +ellps=WGS84"))
    dt = shp@data
    ind = sapply(dt, is.factor)
    dt[ind] = lapply(dt[ind], as.character)
    dt$Lng = shp@coords[,1]
    dt$Lat = shp@coords[,2]
  } else if (grepl("\\.kml",file)) {
    # get layer name from ogrinfo
    shp = readOGR(file, "Features")
    shp = spTransform(shp, CRS("+proj=longlat +ellps=WGS84"))
    dt = shp@data
    ind = sapply(dt, is.factor)
    dt[ind] = lapply(dt[ind], as.character)
    dt$Lng = shp@coords[,1]
    dt$Lat = shp@coords[,2]
  }
  
  # Standardize lat,lng to "Lat","Lng"
  if (all(latlng %in% names(dt))) {
    names(dt)[names(dt) == latlng[1]] = "Lat"
    names(dt)[names(dt) == latlng[2]] = "Lng"
  } else {
    warning('No coordinates available!')
  }
  
  # return
  return(dt)
}

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
# Rating : -1 = avoid, 1 = include, 2 = include (but maybe disable in database), 3 = research further
load.key = function(keyfile = NULL) {
  if (is.null(keyfile)) {
    keyfile = '~/sites/falling-fruit/data/species_key.csv'
  }
	key = read.csv(keyfile, stringsAsFactors=F)
	key$Common = gsub("[ ]+"," ",key$Common)
	key$Common = gsub("[ ]+$|^[ ]+","",key$Common)
	key$Common = capwords(key$Common, strict = T, first = T)
	key$Scientific = gsub("[ ]+"," ",key$Scientific)
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
	return(key)
}

####
## Format

## Capitalize first letter of each word
capwords = function(s, strict = FALSE, first = FALSE) {
	cap = function(s) {
		paste(toupper(substring(s,1,1)), {s = substring(s,2); if(strict) tolower(s) else s}, sep = "", collapse = " " )
	}
	if (first) {
	  s = sapply(s, cap, USE.NAMES = !is.null(names(s))) # Capitalize first character
	  s = gsub("^([^a-zA-Z]*)([a-zA-Z])", "\\1\\U\\2", s, perl = T)
	} else {
	  s = sapply(strsplit(s, split = " "), cap, USE.NAMES = !is.null(names(s))) # Capitalize letter proceeding " "
	  s = gsub("(,|\\.|/|\\()([a-z])", "\\1\\U\\2", s, perl=T)	# Capitalize letter proceeding (,/
	  s = gsub("'([a-z])([a-z])", "'\\U\\1\\L\\2", s, perl=T)	# Capitalize letter proceeding ' if followed by letter
	}
	return(s)
}

## Format specialty string fields (scientific name, address)
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
		x = gsub(" species| spp( |$)| ssp( |$)| sp( |$)"," sp\\1",x,ignore.case=T) # species -> sp
		x = gsub("(^[a-zA-Z]+$)","\\1 sp",x) # Genus -> add sp
		x = capwords(x, strict = F, first = T)
	}
	return(x)
}

####
## Filter
filter.data = function(dt, genus = TRUE) {

	# load key
	key = load.key()
	# remove common name synonyms and multi-species
	key = key[key$Tag != "cyn" & key$Tag != "msp",]
	
	# pre-filter (genus)
	if (genus) {
		ind = grepl(paste(unique(key$Genus[key$Rating > 0]),collapse="|^"),dt$Scientific,ignore.case=T)
		dt = dt[ind,]
	}
		
	# filter (species)
	dt$Type = NA
	dt$Rating = NA
	dt$Human = NA
	dt$Tag = NA
	CPU = 6
	blocks = CPU
	N = nrow(dt)
	starts = seq(1,N,round(N/CPU))
	stops = c(starts[-1]-1,N)
	dt = foreach(i=1:length(starts),.combine = rbind) %dopar% { 
		cdt = dt[starts[i]:stops[i],]
		cropind = rep(TRUE,nrow(cdt))
		for (i in 1:nrow(key)) {
			ind = grepl(paste(key$ScientificSP[i],"( |$)",sep=""),cdt$Scientific[cropind],ignore.case=T)
			if (sum(ind) > 0) {
				cdt$Type[cropind][ind] = key$Common[i]
				cdt$Rating[cropind][ind] = key$Rating[i]
				cdt$Human[cropind][ind] = key$Human[i]
				cdt$Tag[cropind][ind] = key$Tag[i]
				cropind[cropind][ind] = FALSE
			}
		}
		cdt
	}
}

filter.data.common = function(dt) {

	# load key
	key = load.key()
	# remove latin synonyms, misspelled latin names, and empty common names
	key = key[key$Tag != "syn" & key$Tag != "mis" & key$Common != "",]

	# filter
	dt$Type = NA
	dt$Scientific = NA
	dt$Rating = NA
	dt$Human = NA
	dt$Tag = NA
	CPU = 6
	blocks = CPU
	N = nrow(dt)
	starts = seq(1,N,round(N/CPU))
	stops = c(starts[-1]-1,N)
	dt = foreach(i=1:length(starts),.combine = rbind) %dopar% { 
		cdt = dt[starts[i]:stops[i],]
		cropind = rep(TRUE,nrow(cdt))
		for (i in 1:nrow(key)) {
			ind = grepl(paste("^",key$Common[i],"$",sep=""),cdt$Common[cropind],ignore.case=T)
			if (sum(ind) > 0) {
				cdt$Type[cropind][ind] = key$Common[i]
				cdt$Scientific[cropind][ind] = key$ScientificSP[i]
				cdt$Rating[cropind][ind] = key$Rating[i]
				cdt$Human[cropind][ind] = key$Human[i]
				cdt$Tag[cropind][ind] = key$Tag[i]
				cropind[cropind][ind] = FALSE
			}
		}
		cdt
	}
	
	# switch out common name synonyms
  ind = !is.na(dt$Tag) & dt$Tag == "cyn"
  if (sum(ind) > 0) {
    dt = rbind(dt[!ind,], filter.data(dt[ind,], genus = F))
  }
  
  return(dt)
}

# export a csv with unique species field combinations for manual review
initialize.manual.key = function(dt, keyfile, speciesfields = intersect(names(dt),c("Common","Scientific_ori")), manualfields = c("Scientific","Type","Unverified","Description"), sortfield = ifelse("Scientific_ori" %in% names(dt), "Scientific_ori", "Common")) {
  if (!file.exists(keyfile)) {
    inc = dt[is.na(dt$Type), c(speciesfields), drop = F]
    inc = inc[order(inc[sortfield]), , drop = F]
    inc[manualfields] = ""
    write.csv(unique(inc), keyfile, row.names = F)
  } else {
    warning('File already exists!')
  }
}

# load manually entered matches
load.manual.key = function(dt, keyfile, speciesfields = c("Common","Scientific_ori")) {
  if (file.exists(keyfile)) {
   
    # prepare key
    species = read.csv(keyfile, stringsAsFactors=F)
    speciesfields = names(species)[names(species) %in% speciesfields]
    manualfields = names(species)[!names(species) %in% speciesfields]
    ind = rowSums(is.na(species[, manualfields]) | species[, manualfields] == "") < length(manualfields)
    species = species[ind,]
    if ("Scientific" %in% manualfields) {
      species$Scientific = format.field(species$Scientific, 'species')
    }
    if ("Common" %in% manualfields) {
      species$Common = species$Common
    }
    
    # apply key
    speciesString = apply(dt[,speciesfields, drop = F], 1, paste, collapse = " ")
    dt[manualfields[!manualfields %in% names(dt)]] = NA
    for (i in 1:nrow(species)) {
      ind = speciesString == apply(species[i,speciesfields, drop = F], 1, paste, collapse = " ")
      dt[ind, manualfields] = species[i, manualfields]
    }

    # update from latin name
    ind = (is.na(dt$Type) | dt$Type == "") & !is.na(dt$Scientific)
    if (sum(ind) > 0) {
      temp = filter.data(dt[ind,], genus = T)
      dt = rbind(dt[!ind,], temp)
    }

    # update from common name
    ind = (!is.na(dt$Type) & dt$Type != "") & (is.na(dt$Rating) | is.na(dt$Scientific) | dt$Scientific == "")
    if (sum(ind) > 0) {
      temp = dt[ind,]
      temp$Common = temp$Type
      temp = filter.data.common(temp)
      temp$Common = dt$Common[ind]
      ddply(temp[fields], fields, summarise, Count = length(Type))
      dt = rbind(dt[!ind,], temp)
    }

    # switch out common name synonyms
    ind = !is.na(dt$Tag) & dt$Tag == "cyn"
    if (sum(ind) > 0) {
      dt = rbind(dt[!ind,], filter.data(dt[ind,], genus = F))
    }
    
    return(dt)
    
  } else {
    error('File does not exist!')
  }
}


####
## Flatten
# requires: Lat Lng | Address, Type, (Description), (Notes), (Unverified), (Author)
flatten.data = function(data, notesep = ". ") {
	
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
	} else if (length(posfields) > 2 & all(posfields %in% c("Lat","Lng"))) {
		warning(paste("Using Lat & Lng, but location over-defined: ",paste(posfields,collapse=", ")))
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
		ddata = ddply(ddata, c(posfields,typefields), summarize, Description = paste("[",length(Type),"x] ",Description[1],sep=""), Notes = unique.na(Notes), Unverified = max(Unverified,na.rm=T), Access = unique.na(Access), Author = unique.na(Author), .progress = progress, .parallel = parallel)
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