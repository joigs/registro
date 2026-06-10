# app/models/secondary_write.rb
module SecondaryWrite
  class CertChkLstWritable < SecondaryWriteBase
    self.table_name  = "CertChkLst"
    self.primary_key = "CertChkLstId"
  end
end