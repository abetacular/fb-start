require 'geokit'
class Article 
  @@attr_names = ["title", "description", "link", "geo_lat", "geo_long"]
  attr_accessor *@@attr_names
  attr_accessor :location
  include Geokit::Geocoders
  
  def initialize(object)
    if object
      @@attr_names.each do |attr_name|
        if object.has_key?(attr_name.to_sym)
          self.send "#{attr_name}=", object.fetch(attr_name.to_sym)
        end
      end
    end
  end
  
  def location
    return self.geo_lat+","+self.geo_long
  end
  
  # Finding friends within 200 miles of this location.
  def friends(facebook_session)
    article_friends = []
    facebook_session.user.friends_location[0..50].each do |friend_location|
      location = friend_location['current_location']
      begin
        if friend_geocode(location).distance_from(self.location, :units=>:miles).round <= 200
          article_friends << friend_location['name']
        end
      rescue Exception => e 
        puts "Error with Geocoding: #{e} with #{location}"
      end
    end
    return article_friends
  end  
  
  protected 
    # This process takes a real long time. Need to build a cache for this.
    def friend_geocode(location)
      return GoogleGeocoder.geocode(location['city']+","+location['state']+","+location['country'])
    end
end
