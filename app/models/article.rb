class Article < ActiveRecord::Base
  @@api_key = ENV['usa_today_articles_api_key']

  has_many :favorited_articles
  has_many :users, through: :favorited_articles
  default_scope {order('updated_at DESC')}
  # excellent use of has_many through *and* scoping here.

  def self.get_news(section="news", count=15)
    #Generate random coordinates within a given range
    def self.random_coord(min, max)
      rand * (max-min) + min
    end
    #Query USA Today's article API for the first n articles of a given news section
    base_url = "http://api.usatoday.com/open/articles/topnews/"
    query = "#{base_url}/#{section}?count=#{count}&api_key=#{ENV['usa_today_articles_api_key']}"
    response = HTTParty.get(query)
    #Extract list of article metadata from article API's JSON response
    news = response["rss"]["channel"]["item"]
    #Check if articles exist in database. If they don't,
    #add their metadata and generate random coordinates
    news.each do |article|
      link = article["link"]
      if Article.exists?(link: link)
        article = Article.where(link: link).first.update(updated_at: Time.zone.now)
      else
        new_article = create ({
          title: article["title"],
          description: article["description"],
          link: link,
          xcoor: random_coord(37, 45),
          ycoor: random_coord(-79, -70)
        })
        #Add extra metadata (article image and section tag) from the full JSON for each link
        new_article.add_metadata
      end
    end
  end

  #Add extra article image and section metadata using the full JSON for a given article

  def add_metadata
    page_link = link.chomp("/") + ".json"
    site = page_link.split("/")[2].downcase
    #If link is a USA Today site, extract image url from its JSON, get the news category
    #from the URL structure, and update database entry with extra metadata
    # Excellent comments - this makes the code very easy to read.
    if site == "www.usatoday.com" && page_link.split("/")[3] == "story"
      json = HTTParty.get(page_link)
      image_name = json["metadata_modules"][0]["asset_metadata"]["items"]["smallbasename"]
      image_baseurl = json["metadata_modules"][0]["asset_metadata"]["items"]["publishurl"]
      image_url = image_baseurl + image_name
      section = page_link.split("/")[5]
      update(image_url: image_url, section: section)
      # what will happen if this entry does not update successfully?
    else
      #If link not on USA Today domain, add placeholder image and category
      update(image_url: "https://dl.dropboxusercontent.com/u/7989543/general_assembly_logo/GeneralAssemblylogo.jpg",
             section: "External Link")
    end
  end

end
