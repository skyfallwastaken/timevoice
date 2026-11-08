require "test_helper"

class InvoiceSettingTest < ActiveSupport::TestCase
  test "limits notes length" do
    setting = invoice_settings(:one)

    setting.notes = "a" * InvoiceSetting::NOTES_MAX_LENGTH
    assert setting.valid?

    setting.notes += "a"
    assert_not setting.valid?
    assert_includes setting.errors[:notes], "is too long (maximum is 2000 characters)"
  end
end
