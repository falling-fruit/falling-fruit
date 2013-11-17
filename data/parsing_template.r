##################################################################################
# City / Location
# Name
# URL
# Comments
# License

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


####
## Filtering: Manual

# export a csv with unique species field combinations for manual review
# Type, Description, and Unverified columns must be added and completed as needed for desired species
speciesfile = ''
speciesfield = c()
if (!file.exists(speciesfile)) {
  write.csv(unique(dt[,speciesfield]), speciesfile, row.names = F)
}

# apply species filter
species = read.csv(speciesfile, stringsAsFactors=F)
species = species[species$Type != "",]
speciesString = apply(dt[,speciesfield], 1, paste, collapse = " ")
for (i in 1:nrow(species)) {
  ind = speciesString == apply(species[i,speciesfield], 1, paste, collapse = " ")
	dt$Type[ind] = species$Type[i]
	dt$Unverified[ind] = species$Unverified[i]
	dt$Description[ind] = species$Description[i]
}
dt = dt[!is.na(dt$Type),]

# remove species
# NA: none, "": all, "|": list by type
tier2 = NA
tier2 = paste("^", tier2, "$", sep = "", collapse = "|")
ind = grepl(tier2, dt$Type, ignore.case = T)
dt = dt[!ind,]
table(dt$Type)

####
## Filtering: Species Key

## Format fields

# prepare Common
dt$Common = format.field(dt$Common.Name)

# prepare Scientific
dt$Scientific = format.field(dt$Scientific.Name,'species')

# finalize fields
dt$Scientific_ori = dt$Scientific
dt$Scientific = gsub("[ ]+[a-z][ ]+"," ",dt$Scientific,ignore.case=T)
dt = dt[order(dt$Scientific),]
unique(dt[intersect(c("Scientific","Common"),names(dt))])

# apply key
temp = filter.data(dt, genus = T)
fields = intersect(c("Scientific_ori","Common","Type","Rating"), names(temp))
ddply(temp[fields], fields, summarise, Count = length(Type))

# upgrade tier 2 species
# NA: none, "": all, "|": list by type
tier2 = NA
tier2 = paste("^", tier2, "$", sep = "", collapse = "|")
temp$Rating[grepl(tier2, temp$Type, ignore.case = T) & temp$Rating == 2] = 1
table(temp$Type[temp$Rating == 1])
table(temp$Type[temp$Rating == 2])

# commit choices
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

# format: access
dt$Access = NA

# format: author
dt$Author = author

# format: coordinates
lngCol = ""
latCol = ""
names(dt)[names(dt) == lngCol] = "Lng"
names(dt)[names(dt) == latCol] = "Lat"

# format: address
addressCol = ""
streetCol = ""
cityString = ""
dt$Street = format.field(dt[,streetCol], 'address')
dt$Address = paste(dt[,streetCol], " ", dt$Street, ", ", cityString, sep = "")
sort(unique(dt$Address))

# format: notes
dt$Notes = NA
sort(unique(dt$Notes))

####
## Flatten
fdt = flatten.data(dt)
unique(fdt[c("Type","Description")])

####
## Export
export.data(fdt, file, dropfields = T)

####
## Summary
fields = intersect(c("Scientific","Common","Type"),names(dt))
ddply(dt[fields], fields, summarise, Count = length(Type))