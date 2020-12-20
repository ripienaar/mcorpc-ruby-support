class MCollective::Application::Facts < MCollective::Application # rubocop:disable Style/ClassAndModuleChildren
  description "Reports on usage for a specific fact"

  def post_option_parser(configuration)
    configuration[:fact] = ARGV.shift unless ARGV.empty?
  end

  def validate_configuration(configuration)
    raise "Please specify a fact to report for" unless configuration.include?(:fact)
  end

  def show_single_fact_report(fact, facts, verbose=false)
    puts("Report for fact: #{fact}\n\n")

    facts = stringify_facts_hash(facts)

    field_size = MCollective::Util.field_size(facts.keys)
    facts.keys.sort.each do |k|
      printf("        %-#{field_size}s found %d times\n", k, facts[k].size)

      next unless verbose

      puts

      facts[k].sort.each do |f|
        puts("            #{f}")
      end

      puts
    end
  end

  def stringify_facts_hash(facts)
    res = Hash.new([])
    facts.each { |k, v| res[k.to_s] += v }
    res
  end

  def main
    rpcutil = rpcclient("rpcutil")
    rpcutil.progress = false

    facts = {}

    rpcutil.get_fact(:fact => configuration[:fact]) do |resp|
      begin
        value = resp[:body][:data][:value].to_s

        if resp[:body][:data].include?(:value)
          if facts.include?(value)
            facts[value] << resp[:senderid]
          else
            facts[value] = [resp[:senderid]]
          end
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        warn "Could not parse facts for #{resp[:senderid]}: #{e.class}: #{e}"
      end
    end

    if facts.empty?
      puts "No values found for fact #{configuration[:fact]}\n"
    else
      show_single_fact_report(configuration[:fact], facts, options[:verbose])
    end

    printrpcstats

    halt rpcutil.stats
  end
end
