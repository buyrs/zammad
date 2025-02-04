# Copyright (C) 2012-2024 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Whatsapp::Webhook::Message::Text, :aggregate_failures, current_user_id: 1 do
  describe '#process' do
    let(:channel) { create(:whatsapp_channel) }

    let(:from) do
      {
        phone: Faker::PhoneNumber.cell_phone_in_e164.delete('+'),
        name:  Faker::Name.unique.name,
      }
    end

    let(:json) do
      {
        object: 'whatsapp_business_account',
        entry:  [{
          id:      '222259550976437',
          changes: [{
            value: {
              messaging_product: 'whatsapp',
              metadata:          {
                display_phone_number: '15551340563',
                phone_number_id:      channel.options[:phone_number_id],
              },
              contacts:          [{
                profile: {
                  name: from[:name],
                },
                wa_id:   from[:phone],
              }],
              messages:          [{
                from:      from[:phone],
                id:        'wamid.HBgNNDkxNTE1NjA4MDY5OBUCABIYFjNFQjBDMUM4M0I5NDRFNThBMUQyMjYA',
                timestamp: '1707921703',
                text:      {
                  body: 'Hello, world!',
                },
                type:      'text',
              }],
            },
            field: 'messages',
          }],
        }],
      }.to_json
    end

    let(:data) { JSON.parse(json).deep_symbolize_keys }

    context 'when all data is valid' do
      it 'creates a user' do
        expect { described_class.new(data:, channel:).process }.to change(User, :count).by(1)
      end

      it 'creates a ticket + an article' do
        described_class.new(data:, channel:).process

        expect(Ticket.last).to have_attributes(
          title:    "New WhatsApp message from #{from[:name]} (+#{from[:phone]})",
          group_id: channel.group_id,
        )
        expect(Ticket.last.preferences).to include(
          channel_id: channel.id,
          whatsapp:   {
            from:      {
              phone_number: from[:phone],
              display_name: from[:name],
            },
            timestamp: '1707921703',
          },
        )

        expect(Ticket::Article.last).to have_attributes(
          body:         'Hello, world!',
          content_type: 'text/plain',
        )
        expect(Ticket::Article.last.preferences).to include(
          whatsapp: {
            entry_id:   '222259550976437',
            message_id: 'wamid.HBgNNDkxNTE1NjA4MDY5OBUCABIYFjNFQjBDMUM4M0I5NDRFNThBMUQyMjYA',
            type:       'text',
          }
        )
      end
    end
  end
end
