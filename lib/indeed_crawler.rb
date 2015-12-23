require 'json'
require 'uri'
require 'requestmanager'
require 'nokogiri'

class IndeedCrawler
  def initialize(search_query, location, proxy_list, wait_time, browser_num)
    # Info for query
    @search_query = search_query
    @location = location

    # Settings for request manager
    @requests = RequestManager.new(proxy_list, wait_time, browser_num)

    # Result tracking
    @all_resume_links = Array.new
    @output = Array.new
  end

  # Append query
  def add_query(url)
    url += "&q="+URI.encode_www_form([@search_query])
  end

  # Append location
  def add_location(url)
    url += "&" if @search_query
    url += "l="+URI.encode_www_form([@location])
  end

  # Get the links on the page
  def get_page_links(html)
    # Get list of people
    profiles = html.xpath("//li[@itemtype='http://schema.org/Person']")

    # Get each profile link
    profiles.each do |profile|
      @all_resume_links.push("http://indeed.com/"+profile.xpath(".//a[@class='app_link']")[0]['href'])
    end

    # Navigate to next page if there's a class to do that
    load_next_page(html) if !html.css("a.next").empty?
  end

  # Load the next page
  def load_next_page(html)
    next_html = load_restart_page("http://indeed.com/resumes"+html.css("a.next").first['href'], 0)
    get_page_links(Nokogiri::HTML(next_html))
  end

  # Load the page and return or restart and retry if needed
  def load_restart_page(url, count)
    begin
      return @requests.get_page(url)
    rescue
      if count < 2
        @requests.restart_browser
        load_restart_page(url, count+=1)
      end
    end
  end

  # Download and parse all resumes
  def parse_resumes
    @all_resume_links.each do |link|
      resume = load_restart_page(link, 0)
      binding.pry
      # TODO: Parse resume
      # TODO: Add to output- by job listing, arr
    end
  end

  # Get all the profile links
  def collect_it_all
    # Generate URL
    url = "http://indeed.com/resumes?co=US"
    url = add_query(url) if @search_query
    url = add_location(url) if @location

    # Get first page and navigate the rest
    page_body = load_restart_page(url, 0)
    html = Nokogiri::HTML(page_body)
    get_page_links(html)

    # Get and parse all results
    parse_resumes

    # Close browsers when done and return results
    @requests.close_all_browsers
    return JSON.pretty_generate(@output)
  end
end

# TODO: Make gem

i = IndeedCrawler.new("xkeyscore", nil, "/home/shidash/superproxylist", [0.2, 0.3], 1)
i.collect_it_all
