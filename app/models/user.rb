require 'digest/sha1'

class User < ActiveRecord::Base
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken

  validates_presence_of     :login
  validates_length_of       :login,    :within => 3..40
  validates_uniqueness_of   :login
  validates_format_of       :login,    :with => Authentication.login_regex, :message => Authentication.bad_login_message

  validates_format_of       :name,     :with => Authentication.name_regex,  :message => Authentication.bad_name_message, :allow_nil => true
  validates_length_of       :name,     :maximum => 100

  validates_presence_of     :email
  validates_length_of       :email,    :within => 6..100 #r@a.wk
  validates_uniqueness_of   :email
  validates_format_of       :email,    :with => Authentication.email_regex, :message => Authentication.bad_email_message

  
  has_many :streams
  has_many :fb_friends

  # HACK HACK HACK -- how to do attr_accessible from here?
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :name, :password, :password_confirmation

  after_create :register_user_to_fb

  #find the user in the database, first by the facebook user id and if that fails through the email hash
  def self.find_by_fb_user(fb_user)
    User.find_by_fb_user_id(fb_user.uid) || User.find_by_email_hash(fb_user.email_hashes)
  end
  #Take the data returned from facebook and create a new user from it.
  #We don't get the email from Facebook and because a facebooker can only login through Connect we just generate a unique login name for them.
  #If you were using username to display to people you might want to get them to select one after registering through Facebook Connect
  def self.create_from_fb_connect(fb_user)
    new_facebooker = User.new(:name => fb_user.name, :login => "facebooker_#{fb_user.uid}", :password => "", :email => "")
    new_facebooker.fb_user_id = fb_user.uid.to_i
    #We need to save without validations
    new_facebooker.save(false)
    new_facebooker.register_user_to_fb
  end

  #We are going to connect this user object with a facebook id. But only ever one account.
  def link_fb_connect(fb_user_id)
    unless fb_user_id.nil?
      #check for existing account
      existing_fb_user = User.find_by_fb_user_id(fb_user_id)
      #unlink the existing account
      unless existing_fb_user.nil?
        existing_fb_user.fb_user_id = nil
        existing_fb_user.save(false)
      end
      #link the new one
      self.fb_user_id = fb_user_id
      save(false)
    end
  end

  #The Facebook registers user method is going to send the users email hash and our account id to Facebook
  #We need this so Facebook can find friends on our local application even if they have not connect through connect
  #We hen use the email hash in the database to later identify a user from Facebook with a local user
  def register_user_to_fb
    users = {:email => email, :account_id => id}
    Facebooker::User.register([users])
    self.email_hash = Facebooker::User.hash_email(email)
    save(false)
  end
  def facebook_user?
    return !fb_user_id.nil? && fb_user_id > 0
  end
  
  def self.is_a_facebook_friend?(facebook_session, facebook_user)
    return facebook_session.user.friends.include?(facebook_user.fb_user_id)
  end
  
  def self.facebook_friends_locations(facebook_session, current_user)
    friends_location = []
    friends = current_user.fb_friends
    if friends.size > 1
      friends.each do |f|
        friends_location << friend = {:name => f.name, :uid => f.fb_user_id, :geo => Marshal.load(f.location)} 
      end
    else
      @friend_locations = facebook_session.user.friends_location
      friends_locations = @friend_locations
      # Find all friends Geo Data
      friends_locations.each do |friend_loc|
        location = friend_loc['current_location']
        if location
          @fb_friends = FbFriend.find(:all, :select => "fb_user_id").collect {|x| x.fb_user_id }
          unless @fb_friends.include?(friend_loc['uid'].to_i)
            friends_location << fb_loc = {:geo => Article.friend_geocode(location), :name => friend_loc['name'], :uid => friend_loc['uid']}
            fb_friend = FbFriend.new(:user_id => current_user.id, :fb_user_id => friend_loc['uid'], :name => friend_loc['name'], :location => Marshal.dump(fb_loc[:geo]))
            fb_friend.save!
          end
        end
      end
    end
    return friends_location
  end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  #
  # uff.  this is really an authorization, not authentication routine.  
  # We really need a Dispatch Chain here or something.
  # This will also let us return a human error message.
  #
  def self.authenticate(login, password)
    return nil if login.blank? || password.blank?
    u = find_by_login(login.downcase) # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  def login=(value)
    write_attribute :login, (value ? value.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.downcase : nil)
  end
  
  def new_stream(stream)
    stream.user_id = self.id
    stream.save!
  end

  protected
    


end
