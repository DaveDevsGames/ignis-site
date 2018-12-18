require 'yaml'
require 'json'
require 'open-uri'

Jekyll::Hooks.register :site, :after_init do |site|
  YAML_FRONT_MATTER_REGEXP = %r!\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)!m.freeze
  FLAG_FRONT_MATTER = 'directus'
  POST_LAYOUT = 'post'
  TARGET_DIR = '_posts'

  # Look at existing posts and remove any with front matter that flags them as
  # content from the CMS.
  Jekyll.logger.info "Deleting old CMS posts..."
  Dir.entries(TARGET_DIR).each do |post_filename|
    post_file_path = File.join(TARGET_DIR, post_filename)
    if File.file?post_file_path
      post_file_content = File.read(post_file_path)
      post_file_content =~ YAML_FRONT_MATTER_REGEXP
      post_front_matter = YAML.load($1)
      if post_front_matter.has_key? FLAG_FRONT_MATTER
        File.delete(post_file_path)
      end
    end
  end

  # Data pulled from web API.
  Jekyll.logger.info "Downloading CMS posts..."
  json_config = JSON.parse(File.read(File.join(__dir__, 'cms_config.json')))
  api_token = json_config['api_token']
  posts_uri = json_config['api_uri'] + json_config['api_posts_endpoint']
  posts_io = open(posts_uri, "Authorization" => "Bearer #{api_token}")
  cms_posts = JSON.parse(posts_io.read)['data']
  authors_uri = json_config['api_uri'] + json_config['api_authors_endpoint']
  authors_io = open(authors_uri, "Authorization" => "Bearer #{api_token}")
  cms_authors = JSON.parse(authors_io.read)['data']
  authors = Hash.new
  cms_authors.each do |author|
    authors[author['id']] = author['first_name'] << ' ' << author['last_name']
  end

  # Create a new file for each post from the CMS. Matching Jekyll's naming
  # convention for blog posts to allow it to take over the rest of the build.
  # Layout and the CMS flag front matter are added to the pulled front matter.
  Jekyll.logger.info "Creating fresh CMS posts..."
  cms_posts.each do |post|
    post_datetime = DateTime.strptime(post['published_date'], "%Y-%m-%d %H:%M:%S")
    post_filename = post_datetime.strftime("%Y-%m-%d") << '-' << post['title'].gsub(/\s+/, '').downcase << '.md'
    post_file_path = File.join(TARGET_DIR, post_filename)
    if File.file?post_file_path
      Jekyll.logger.warn "A post named #{post_filename} already exists. Skipped"
    else
      post_file = File.open(File.join(TARGET_DIR, post_filename), 'w')
      post_file.puts '---'
      post_file.puts "#{FLAG_FRONT_MATTER}: true"
      post_file.puts "layout: #{POST_LAYOUT}"
      post.each_pair do |front_matter, value|
        if front_matter == 'markdown_content'
          next
        elsif front_matter == 'author'
          post_file.puts "author: #{authors[value]}"
        else
          post_file.puts "#{front_matter}: #{value}"
        end
      end
      post_file.puts '---'
      post_file.puts post['markdown_content']
      post_file.close
    end
  end
end
