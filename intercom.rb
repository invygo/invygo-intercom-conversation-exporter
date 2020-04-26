require 'json'
require 'intercom'

class ConvoParser
  attr_reader :intercom, :output_file

  def initialize(client, file_name)
    @intercom = client
    @output_file = file_name
    File.write(file_name, "")
    write_to_file("convo_id,message_id,message_body,type,author_id")  
  end

  def write_to_file(content)
    File.open(output_file, 'a+') do |f|
      f.puts(content.to_s + "\n")
    end
  end

  def parse_single_convo(convo)
    puts "<XXXXXXXXXXXXX CONVERSATION XXXXXXXXXXXXX>"
    puts JSON.pretty_generate(convo)
    puts "<XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX>"
  end

  def parse_conversation_part(convo_id, convo_part)
    # write_to_file("PART ID: #{convo_part.id}")
      # write_to_file("From: #{convo_part.author.id}")
      # convo_part.body.slice! "<p>"
      # authorintercom.contacts.find(id: convo_part.author.id)
      # if convo_part.author.id

      # end
      if convo_part.body
        convo_part.body.slice! ","
        convo_part.body.slice! "\n"
        convo_part.body.slice! "<p>"
        convo_part.body.slice! "</p>"
        convo_part.body.delete! "\n"
        convo_part.body.delete! "<br>"
        write_to_file("#{convo_id},#{convo_part.id},#{convo_part.body},#{convo_part.part_type},#{convo_part.author.id}")  
      end
  end

  def parse_conversation_parts(convo)
    total_count = convo.conversation_parts.length
    current_count = 0
    # write_to_file("CONVO ID: #{convo.id}")
    # write_to_file("NUM PARTS: #{total_count}")
    # write_to_file("<XXXXXXXXXX CONVERSATION XXXXXXXXXX>")
    convo.conversation_parts.each do |convo_part|
      # write_to_file("PART #{current_count+=1} OF #{total_count}")
      parse_conversation_part(convo.id,convo_part)
    end
    # write_to_file("<XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX>")

  end

  def check_rate_limit
    current_rate = yield
    # write_to_file("RATE LIMIT: #{intercom.rate_limit_details[:remaining]}")
    if intercom.rate_limit_details[:remaining] < 30
      sleep 10
      write_to_file("SLEEPING")
    end
    current_rate
  end
end

class ConvoSetup
  attr_reader :intercom, :convo_parser

  def initialize(access_token, file_name)
    # You should alwasy store you access token in a environment variable
    # This ensures you never accidentally expose it in your code
    @intercom = Intercom::Client.new(token: "Your Token Here")
    @convo_parser = ConvoParser.new(intercom, file_name)
  end

  def get_single_convo(convo_id)
    # Get a single conversation
    convo_parser.check_rate_limit do
      intercom.conversations.find(id: convo_id)
    end
  end

  def get_first_page_of_conversations()
    # Get the first page of your conversations
    convo_parser.check_rate_limit do
      convos = intercom.get("/conversations", "")
      convos
    end
  end

  def get_next_page_of_conversations(next_page_url)
    # Get the first page of your conversations
    convos = intercom.get(next_page_url, "")
    convos
  end

  def run
    # Need to check if there are multiple pages of conversations
    # write_to_file("convo_id,message_id,message_body,type,author_id")  
    # author = intercom.contacts.find(id: "3794266")
    # puts JSON.pretty_generate(author)
    result = get_first_page_of_conversations
    # Set this to TRUE initially so we process the first page
    current_page = 1
    count = 1
    total = result["pages"]["per_page"] * result["pages"]["total_pages"]

    until current_page.nil? do
      # Parse through each conversation to see what is provided via the list
      result["conversations"].each do |single_convo|
        puts "Exporting conversation #{count} of #{total}"
        convo_parser.parse_conversation_parts(get_single_convo(single_convo['id']))
        count +=1
      end
      puts "PAGINATION: page #{result['pages']['page']} of #{result["pages"]["total_pages"]}"
      convo_parser.write_to_file("PAGE #{result['pages']['page']}")
      current_page = result['pages']['next']
      if current_page.nil?
        # Dont make any more calls since we are on the last page
        break
      end
      result = get_next_page_of_conversations(result['pages']['next'])
    end
  end
end

ConvoSetup.new("AT", "convo_output.txt").run