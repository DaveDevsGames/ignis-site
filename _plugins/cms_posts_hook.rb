require 'yaml'
require 'json'
require 'open-uri'
require 'fileutils'

YAML_FRONT_MATTER_REGEXP = %r!\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)!m.freeze
FILENAME_REGEXP = /[\w.]+$/.freeze

$json_config = nil

def parse_json_config
  json_config_filepath = File.join(__dir__, 'cms_config.json')
  begin
    $json_config = JSON.parse(File.read(json_config_filepath))
  rescue
    Jekyll.logger.error "CMS Config:", "Failed to read #{json_config_filepath}"
  else
    Jekyll.logger.info "CMS Config:", "#{json_config_filepath}"
    return true
  end
  return false
end

def clear_api_posts
  num_cleared = 0
  begin
    posts_dir = $json_config['posts_dir']
    front_matter_flag = $json_config['front_matter_flag']
  rescue
    Jekyll.logger.error "CMS Config:", "Config file is malformed."
  else
    Dir.entries(posts_dir).each do |post_filename|
      post_file_path = File.join(posts_dir, post_filename)
      if File.file?post_file_path
        post_file_content = File.read(post_file_path)
        post_file_content =~ YAML_FRONT_MATTER_REGEXP
        post_front_matter = YAML.load($1)
        if post_front_matter.has_key? front_matter_flag
          File.delete(post_file_path)
          num_cleared += 1
        end
      end
    end
  end
  return num_cleared
end

def read_api_data(api_token, target_uri)
  begin
    data_io = open(target_uri, "Authorization" => "Bearer #{api_token}")
  rescue
    Jekyll.logger.error "Endpoint:", "Failed to reach #{target_uri}"
  else
    begin
      data = JSON.parse(data_io.read)['data']
    rescue
      Jekyll.logger.error "Endpoint:", "Reached #{target_uri} but failed to parse data."
    else
      Jekyll.logger.info "Endpoint:", "Reached #{target_uri} and parsed data successfully."
      return data
    end
  end
  return nil
end

def get_api_posts
  begin
    api_token = $json_config['api_token']
    posts_uri = $json_config['api_uri'] + $json_config['api_posts_endpoint']
  rescue
    Jekyll.logger.error "CMS Config:", "Config file is malformed."
  else
    return read_api_data(api_token, posts_uri)
  end
  return nil
end

def get_api_authors
  begin
    api_token = $json_config['api_token']
    authors_uri = $json_config['api_uri'] + $json_config['api_authors_endpoint']
  rescue
    Jekyll.logger.error "CMS Config:", "Config file is malformed."
  else
    return read_api_data(api_token, authors_uri)
  end
  return nil
end

def get_api_files
  begin
    api_token = $json_config['api_token']
    files_uri = $json_config['api_uri'] + $json_config['api_files_endpoint']
  rescue
    Jekyll.logger.error "CMS Config:", "Config file is malformed."
  else
    return read_api_data(api_token, files_uri)
  end
  return nil
end

def fetch_image(file_id, files)
  begin
    image_dir = $json_config['image_dir']
  rescue
    Jekyll.logger.error "CMS Config:", "Config file is malformed."
  else
    image_uri = files[file_id]
    if image_uri != nil
      image_filename = FILENAME_REGEXP.match(image_uri)[0]
      if image_filename != nil
        image_filepath = File.join(image_dir, image_filename)
        File.open(image_filepath, 'wb') do |image_file|
          image_file << open(image_uri).read
        end
        Jekyll.logger.info "CMS Image:", "#{image_filepath}"
        return image_filepath
      else
        Jekyll.logger.error "CMS Image:", "#{image_uri} has no valid filename."
      end
    else
      Jekyll.logger.error "CMS Image:", "No image with id #{file_id}"
    end
  end
  return nil
end

def create_post(cms_post, authors, files)
  begin
    posts_dir = $json_config['posts_dir']
    front_matter_layout = $json_config['front_matter_layout']
    front_matter_flag = $json_config['front_matter_flag']
  rescue
    Jekyll.logger.error "CMS Config:", "Config file is malformed."
  else
    begin
      published_date = cms_post['published_date']
      title = cms_post['title']
    rescue
      Jekyll.logger.error "CMS Config:", "Config file is malformed."
    else
      post_datetime = DateTime.strptime(published_date, "%Y-%m-%d %H:%M:%S")
      post_filename = post_datetime.strftime("%Y-%m-%d") << '-' << title.gsub(/\s+/, '').downcase << '.md'
      post_file_path = File.join(posts_dir, post_filename)
      if File.file?post_file_path
        Jekyll.logger.warn "Post:", "A post named #{post_filename} already exists. Skipped"
      else
        post_file = File.open(File.join(posts_dir, post_filename), 'w')
        post_file.puts '---'
        post_file.puts "#{front_matter_flag}: true"
        post_file.puts "layout: #{front_matter_layout}"
        cms_post.each_pair do |front_matter, value|
          if front_matter == 'markdown_content'
            next
          elsif front_matter == 'author'
            post_file.puts "#{front_matter}: #{authors[value]}"
          elsif front_matter == 'image_head'
            file_uri = fetch_image value, files
            if file_uri != nil
              post_file.puts "#{front_matter}: #{file_uri}"
            end
          else
            post_file.puts "#{front_matter}: #{value}"
          end
        end
        post_file.puts '---'
        post_file.puts cms_post['markdown_content']
        post_file.close
        Jekyll.logger.info "Post:", "Created #{post_filename}"
        return post_file_path
      end
    end
  end
  return nil
end

Jekyll::Hooks.register :site, :after_init do |site|
  Jekyll.logger.debug "Begin CMS..."
  if parse_json_config
    # First we download fresh posts. We abort the script if we fail.
    Jekyll.logger.info "Fetch CMS posts..."
    cms_posts = get_api_posts
    if cms_posts == nil
      Jekyll.logger.error "Abort CMS..."
      next
    end
    cms_authors = get_api_authors
    if cms_authors == nil
      Jekyll.logger.error "Abort CMS..."
      next
    else
      authors = Hash.new
      cms_authors.each do |author|
        authors[author['id']] = author['first_name'] << ' ' << author['last_name']
      end
    end
    cms_files = get_api_files
    if cms_files == nil
      Jekyll.logger.error "Abort CMS..."
      next
    else
      files = Hash.new
      cms_files.each do |file|
        files[file['id']] = file['data']['full_url']
      end
    end

    # Second we clear the old posts and report the number.
    Jekyll.logger.info "Clear CMS posts..."
    num_cleared = clear_api_posts
    Jekyll.logger.info "Cleared Posts:", "Cleared #{num_cleared} posts."

    # Create a new file for each post from the CMS. Matching Jekyll's naming
    # convention for blog posts to allow it to take over the rest of the build.
    # Layout and the CMS flag front matter are added to the pulled front matter.
    Jekyll.logger.info "Create CMS posts..."
    begin
      FileUtils.mkdir_p $json_config['image_dir']
    rescue
      Jekyll.logger.error "CMS Config:", "Config file is malformed."
      Jekyll.logger.error "Abort CMS..."
      next
    end
    cms_posts.each do |cms_post|
      create_post cms_post, authors, files
    end

  else
    Jekyll.logger.error "Abort CMS..."
    next
  end
  Jekyll.logger.debug "CMS Success!"
end

Jekyll::Hooks.register :site, :post_write do |site|
  Jekyll.logger.debug "Tidy CMS..."
  if parse_json_config
    begin
      FileUtils.remove_dir($json_config['image_dir'], force=true)
    rescue
      Jekyll.logger.error "Temp Images: Failed to delete."
    end
  end
end
