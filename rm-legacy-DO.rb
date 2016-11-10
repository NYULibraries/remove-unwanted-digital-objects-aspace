require 'rubygems'
require 'bundler/setup'
require 'pry'
require 'multi_json'
require 'yaml'
require 'logger'
require 'archivesspace/client'
#require_relative 'lib/aspace/api'

def parse_nested_hsh(nodes,uris)
  nodes.each { |n|
    uris.push(n['record_uri']) if n['instance_types'].size > 0
    parse_nested_hsh(n['children'],uris) if n['children']
  }
  uris
end

def get_digital_instances(instance)
  instance['digital_object']['ref']
end

def remove_instance_ref(instance,uri)
  modified = instance.dup
  modified = modified.delete_if { |i| i['digital_object']['ref'] == uri if (i.has_key?('digital_object') && i['digital_object'].has_key?('ref'))}
  modified
end
def check_do(instance)
  true if instance['title'] == 'unspecified'
end

def load_config_yaml(config)
  yaml = YAML.load_file(config)
  hsh = {}
  # read yaml hash and symbolize keys to new hash
  # to create config object for archivesspace-client
  yaml.each_key { |k|
    hsh[k.to_sym] = yaml[k]
  }
  hsh
end

def process_archival_object(uri)
  delete_me = []
  info = @client.get(uri)
  if info.status_code == 200
    LOG.info("Processing #{uri}")
    archival_object = info.parsed
    instances = archival_object['instances']
    instances.each { |i|

      do_ref = get_digital_instances(i) if i['digital_object']
      digital_object = @client.get(do_ref)
      if digital_object.status_code == 200
        delete_me << do_ref if check_do(digital_object.parsed)
      else
        LOG.warn("Could not get #{do_ref}: Message #{digital_object.status_code}")
      end
    }
    if delete_me.size > 0
      delete_me.each { |d_uri|
        modified = remove_instance_ref(info.parsed['instances'],d_uri)
        archival_object['instances'] = modified
        #binding.pry
        LOG.info("updating #{uri} to remove reference of digital object to be deleted")
        update = @client.post(archival_object['uri'],archival_object)
        if update.status_code == 200
          LOG.info("Update #{uri} successful")
          status = @client.delete(d_uri)
          if status.status_code == 200
            LOG.info("deleted #{d_uri}")
          else
            LOG.warn("Problem with deletion #{status.status_code}")
          end
        else
          LOG.warn("Couldn't update #{uri}: #{update.status_code}")
        end
      }
    else
      LOG.info("Skipping #{uri}. No deleteable digital objects found")
    end
  else
    LOG.warn("#{uri} could not be accessed")
  end

end

config_file = "config.yml"
hsh = load_config_yaml(config_file)
resource = '383'
repo = 'fales'
file = "logs/#{Time.now.getutc.to_i}.txt"
LOG = Logger.new(file)
config = ArchivesSpace::Configuration.new(hsh)
@client =  ArchivesSpace::Client.new(config).login
repo = @client.repositories.find { |r| r['repo_code'] == repo }
uri = repo['uri'] + "/resources/#{resource}/tree"
records = @client.get(uri).parsed
children = records['children']
uris = []
uris = parse_nested_hsh(children,uris)
chk = uris[0..1]
delete_me = []
uris.each { |uri|
  process_archival_object(uri)
}
