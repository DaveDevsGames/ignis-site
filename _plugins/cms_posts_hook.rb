require 'yaml'
require 'json'

Jekyll::Hooks.register :site, :after_init do |site|
  YAML_FRONT_MATTER_REGEXP = %r!\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)!m.freeze

  flag_front_matter = 'directus'
  post_layout = 'post'
  target_dir = '_posts'

  # Look at existing posts and remove any with front matter that flags them as
  # content from the CMS.
  Dir.entries(target_dir).each do |post_filename|
    post_file_path = File.join(target_dir, post_filename)
    if File.file?post_file_path
      post_file_content = File.read(post_file_path)
      post_file_content =~ YAML_FRONT_MATTER_REGEXP
      post_front_matter = YAML.load($1)
      if post_front_matter.has_key? flag_front_matter
        File.delete(post_file_path)
      end
    end
  end

  # Reading temporary local file for testing. To be replaced with data pulled
  # via a RESTful API.
  json_posts = JSON.parse(File.read(File.join(__dir__, 'content-test.json')))['posts']

  # Create a new file for each post from the CMS. Matching Jekyll's naming
  # convention for blog posts to allow it to take over the rest of the build.
  # Layout and the CMS flag front matter are added to the pulled front matter.
  json_posts.each do |post|
    post_datetime = DateTime.strptime(post['published_date'], "%Y-%m-%d %H:%M:%S")
    post_filename = post_datetime.strftime("%Y-%m-%d") << '-' << post['title'].gsub(/\s+/, '').downcase << '.md'
    post_file = File.open(File.join(target_dir, post_filename), 'w')
    post_file.puts '---'
    post_file.puts "#{flag_front_matter}: true"
    post_file.puts "layout: #{post_layout}"
    post.each_pair do |front_matter, value|
      if front_matter == 'content'
        next
      end
      post_file.puts "#{front_matter}: #{value}"
    end
    post_file.puts '---'
    post_file.puts post['content']
    post_file.close
  end
end
