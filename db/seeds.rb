# --- API key
ApiKey.create(api_key: 'AKDJGHSD')

# --- Admin user with foraging range
admin = User.new(
  email: 'admin@fallingfruit.org',
  password: 'password',
  password_confirmation: 'password',
  name: 'Admin',
  roles: ['admin', 'forager'],
  range_radius: 5,
  range_radius_unit: 'km',
  lat: 39.986606,
  lng: -105.242404
)
admin.confirmed_at = Time.zone.now
admin.save!

# --- Regular user with bio
user = User.new(
  email: 'user@fallingfruit.org',
  password: 'password',
  password_confirmation: 'password',
  name: 'User',
  bio: 'Mulberries are my favorite fruit.',
  roles: ['forager']
)
user.confirmed_at = Time.zone.now
user.save!

# --- Parent type
parent = Type.create!(
  en_name: 'Apple',
  fr_name: 'Pommier',
  scientific_name: 'Malus',
  wikipedia_url: 'http://en.wikipedia.org/wiki/Malus',
  taxonomic_rank: 6,  # genus
  category_mask: 1,  # forager
  pending: false
)

# --- Child type
child = Type.create!(
  en_name: 'Apple',
  fr_name: 'Pommier commun',
  scientific_name: 'Malus domestica',
  wikipedia_url: 'http://en.wikipedia.org/wiki/Malus_domestica',
  taxonomic_rank: 8,  # species
  category_mask: 1,  # forager
  parent_id: parent.id,
  pending: false
)
