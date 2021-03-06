# encoding: utf-8
require "base64"

module IfreeSms
  module Smsing
    def self.included(base)
      base.send :include, InstanceMethods
      base.send :extend,  ClassMethods
    end
    
    module ClassMethods
      def self.extended(base)
        base.class_eval do
          # Associations
          belongs_to :messageable, :polymorphic => true
          
          # Validations
          validates :sms_id, :phone, :service_number, :sms_text, :now, :presence => true
          validate :check_secret_key

          attr_accessible :request
          attr_accessor :md5key, :test, :answer_text
          
          scope :with_messageable, lambda { |record| where(["messageable_id = ? AND messageable_type = ?", record.id, record.class.name]) }
        end
      end
    end
    
    module InstanceMethods
      
      def request
        @request
      end
      
      def request=(req)
        self.sms_id = req.params["smsId"].to_i
        self.phone = req.params["phone"].to_i
        self.service_number = req.params["serviceNumber"].to_i
        self.encoded_sms_text = req.params["smsText"]
        self.now = parse_date(req.params["now"])
        self.md5key = req.params["md5key"]
        self.test = req.params["test"]
        
        @request = req
      end
      
      def encoded_sms_text
        @encoded_sms_text
      end
      
      def encoded_sms_text=(value)
        self.sms_text = Base64.decode64(value) unless value.blank? 
        @encoded_sms_text = value
      end
      
      def to_ifree    
        if self.answer_text.blank?
          "<Response noresponse='true'/>"
        else
          "<Response><SmsText>#{self.answer_text}</SmsText></Response>"
        end   
      end
      
      def test_to_ifree
        "<Response><SmsText>#{self.test}</SmsText></Response>"
      end
      
      def response_to_ifree
        unless self.new_record?
          [self.to_ifree, 200]
        else  
          [self.errors.to_xml, 422]
        end
      end
      
      def test?
        !self.test.blank?
      end
      
      def send_answer(text)
        IfreeSms.send_sms(self.phone, text, self.sms_id)
      end 
      
      protected
        
        def check_secret_key
          errors.add(:md5key, :invalid) unless valid_secret?
        end
        
        def valid_secret?          
          return false if now.nil?
          
          digest = IfreeSms.calc_digest(service_number, encoded_sms_text, now.utc.strftime("%Y%m%d%H%M%S"))
          
          IfreeSms.log("md5key: #{md5key}, calc_digest: #{digest}")
          
          self.md5key == digest
        end
        
        def parse_date(value)
          begin
            DateTime.strptime(value, "%Y%m%d%H%M%S")
          rescue Exception => e
            nil
          end
        end
    end
  end
end
