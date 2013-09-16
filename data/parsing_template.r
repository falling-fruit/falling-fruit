##################################################################################
# CITY
# DATASET
# URL
# COMMENTS

## Set working directory
setwd("~/sites/falling-fruit-data/muni/")

## Import
file = ""
author = ""
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
  i = sapply(dt, is.factor)
  dt[i] = lapply(dt[i], as.character)
  dt$Lng = shp@coords[,1]
  dt$Lat = shp@coords[,2]
}

# remove incomplete rows

####
## Format names

# common
dt$Common = format.field(dt$Common.Name)

# scientific
dt$Scientific = format.field(dt$Scientific.Name,'species')

# special cases

# finalize
dt$Scientific_ori = dt$Scientific
dt$Scientific = gsub("[ ]+[a-z][ ]+"," ",dt$Scientific,ignore.case=T)
dt = dt[order(dt$Scientific),]
unique(dt[intersect(c("Scientific","Common"),names(dt))])

####
## Filter
temp = filter.data(dt, genus = T)
fields = intersect(c("Scientific_ori","Common","Type","Rating"),names(temp))
ddply(temp[fields], fields, summarise, Count = length(Type))

# upgrade tier 2
# NA: none, "": all, "|": list by type
tier2 = NA
tier2 = paste("^",tier2,"$",sep="")
temp$Rating[grepl(gsub("\\|","$|^",tier2),temp$Type,ignore.case=T) & temp$Rating == 2] = 1
table(temp$Type[temp$Rating == 1])
table(temp$Type[temp$Rating == 2])

# commit
dt = temp[temp$Rating == 1 & !is.na(temp$Type) & temp$Type != "",]

####
## Format fields

# format: description
if (all(c("Common","Scientific_ori") %in% names(dt))) {
	dt$Description = paste(dt$Common," (",dt$Scientific_ori,")",sep="")
} else {
	field = intersect(names(dt),c("Scientific_ori","Common"))
	dt$Description = dt[[field]]
}
sort(unique(dt$Description))

# format: unverified
dt$Unverified = ""
ind = grepl("[ ]+sp$",dt$Scientific,ignore.case=T)
dt$Unverified[ind] = "x"
fields = intersect(c("Scientific_ori","Common","Type","Unverified"),names(dt))
unique(dt[order(dt$Unverified,decreasing=T),fields])

# format: author
dt$Author = author

# format: address
dt$Street = format.field(dt$Street,'address')
dt$Address = paste(dt$Number," ",dt$Street,", City, ST",sep="")
sort(unique(dt$Address))

# format: coordinates
names(dt)[names(dt) == "POINT_X"] = "Lng"
names(dt)[names(dt) == "POINT_Y"] = "Lat"

# format: notes
dt$Notes = paste(dt$Number," ",dt$Street,sep="")
# dt$Address = NA
sort(unique(dt$Notes))

####
## Flatten
fdt = flatten.data(dt)
#fdt$Description = gsub("[ ]+@[ ]+Planted",". Planted", dt$Description)
unique(fdt[c("Type","Description")])

####
## Export
export.data(fdt, file, dropfields = T)

####
## Summary
fields = intersect(c("Scientific","Common","Type"),names(dt))
ddply(fdt[fields], fields, summarise, Count = length(Type))