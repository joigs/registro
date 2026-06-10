# app/models/secondary_write.rb
module SecondaryWrite
  class CertChkLstWritable < SecondaryWriteBase
    self.table_name  = "CertChkLst"
    self.primary_key = "CertChkLstId"
  end

  class CerManWritable < SecondaryWriteBase
    self.table_name  = "CerMan"
    self.primary_key = "CerManRut"
  end
end