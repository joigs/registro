class SecondaryModels

  class AuditBuscarExternal < SecondaryBase
    self.table_name = "AuditBuscar"
    self.primary_key = "AuditBuscarId"
  end

  class BiblioExternal < SecondaryBase
    self.table_name = "Biblio"
    self.primary_key = "BiblioId"
  end

  class BiblioTipoExternal < SecondaryBase
    self.table_name = "BiblioTipo"
    self.primary_key = "BiblioTipoId"
  end

  class CerManExternal < SecondaryBase
    self.table_name = "CerMan"
    self.primary_key = "CerManRut"
  end

  class CerManAreaExternal < SecondaryBase
    self.table_name = "CerManArea"
    self.primary_key = "CerManAreaId"
  end

  class CerManEmpExternal < SecondaryBase
    self.table_name = "CerManEmp"
    self.primary_key = "CerManEmpId"
  end

  class CertActivoExternal < SecondaryBase
    self.table_name = "CertActivo"
    self.primary_key = "CertActivoId"
  end

  class CertActivoAreaExternal < SecondaryBase
    self.table_name = "CertActivoArea"
  end

  class CertActivoATrabExternal < SecondaryBase
    self.table_name = "CertActivoATrab"
    self.primary_key = "CertActivoATrabId"
  end

  class CertActivoFotoExternal < SecondaryBase
    self.table_name = "CertActivoFoto"
    self.primary_key = "CertActivoFotoId"
  end

  class CertActivoFoto2External < SecondaryBase
    self.table_name = "CertActivoFoto2"
    self.primary_key = "CertActivoFoto2Id"
  end

  class CertActivoMoverExternal < SecondaryBase
    self.table_name = "CertActivoMover"
  end

  class CertActivoUpExternal < SecondaryBase
    self.table_name = "CertActivoUp"
    self.primary_key = "CertActivoUpId"
  end

  class CertCamaraExternal < SecondaryBase
    self.table_name = "CertCamara"
    self.primary_key = "CertCamaraId"
  end

  class CertCamara2External < SecondaryBase
    self.table_name = "CertCamara2"
    self.primary_key = "CertCamaraId"
  end

  class CertChkItemExternal < SecondaryBase
    self.table_name = "CertChkItem"
    self.primary_key = "CertItemId"
  end

  class CertChkItemDocExternal < SecondaryBase
    self.table_name = "CertChkItemDoc"
    self.primary_key = "CertChkItemDocId"
  end

  class CertChkItemFotoExternal < SecondaryBase
    self.table_name = "CertChkItemFoto"
    self.primary_key = "CertChkItemFotoId"
  end

  class CertChkItemFoto2External < SecondaryBase
    self.table_name = "CertChkItemFoto2"
    self.primary_key = "CertChkItemFoto2Id"
  end

  class CertChkListExternal < SecondaryBase
    self.table_name = "CertChkList"
    self.primary_key = "CertChkListId"
  end

  class CertChkLstExternal < SecondaryBase
    self.table_name = "CertChkLst"
    self.primary_key = "CertChkLstId"
  end

  class CertChkLstItemExternal < SecondaryBase
    self.table_name = "CertChkLstId"
    self.primary_key = "CertChkLstItemFch"
  end

  class CertChkLstValorExternal < SecondaryBase
    self.table_name = "CertChkLstValor"
    self.primary_key = "CertChkLstValorId"
  end

  class CertClaseExternal < SecondaryBase
    self.table_name = "CertClase"
    self.primary_key = "CertClaseId"
  end

  class CertClasePlantillaExternal < SecondaryBase
    self.table_name = "CertClasePlantilla"
    self.primary_key = "CertClasePlantillaId"
  end

  class CertClasePlantillaItemExternal < SecondaryBase
    self.table_name = "CertClasePlantillaItem"
  end

  class CertificateExternal < SecondaryBase
    self.table_name = "Certificate"
    self.primary_key = "CertificateId"
  end

  class CertificateAuthorityExternal < SecondaryBase
    self.table_name = "CertificateAuthority"
    self.primary_key = "CertificateAuthorityId"
  end

  class CertItemExternal < SecondaryBase
    self.table_name = "CertItem"
    self.primary_key = "CertItemId"
  end

  class CertItemCExternal < SecondaryBase
    self.table_name = "CertItemC"
    self.primary_key = "CertItemCId"
  end

  class CertItemPadreExternal < SecondaryBase
    self.table_name = "CertItemPadre"
    self.primary_key = "CertItemPadreId"
  end

  class CertNivelExternal < SecondaryBase
    self.table_name = "CertNivel"
    self.primary_key = "CertNivelId"
  end

  class CertTipoActExternal < SecondaryBase
    self.table_name = "CertTipoAct"
    self.primary_key = "CertTipoActId"
  end

  class ChkHCRExternal < SecondaryBase
    self.table_name = "ChkHCR"
    self.primary_key = "ChkHCRId"
  end

  class DocParentExternal < SecondaryBase
    self.table_name = "DocParent"
    self.primary_key = "DocParentId"
  end

  class DocParentDocExternal < SecondaryBase
    self.table_name = "DocParentDoc"
    self.primary_key = "DocParentDocId"
  end

  class EnvioFTPExternal < SecondaryBase
    self.table_name = "EnvioFTP"
    self.primary_key = "EnvioFTPId"
  end

  class FotoTempExternal < SecondaryBase
    self.table_name = "FotoTemp"
    self.primary_key = "FotoTempId"
  end

  class GXDEVICERESULTExternal < SecondaryBase
    self.table_name = "GXDEVICERESULT"
  end

  class GXPARAMETERSExternal < SecondaryBase
    self.table_name = "GXPARAMETERS"
  end

  class GXRESULTROWSExternal < SecondaryBase
    self.table_name = "GXRESULTROWS"
  end

  class MarcaExternal < SecondaryBase
    self.table_name = "Marca"
    self.primary_key = "MarcaId"
  end

  class MConvExternal < SecondaryBase
    self.table_name = "MConv"
    self.primary_key = "MConv_Id"
  end

  class MConvDestExternal < SecondaryBase
    self.table_name = "MConvDest"
    self.primary_key = "MConvDestId"
  end

  class MConvDestAteExternal < SecondaryBase
    self.table_name = "MConvDestAte"
    self.primary_key = "MConvDestAteId"
  end

  class MConvMailExternal < SecondaryBase
    self.table_name = "MConvMail"
  end

  class MConvODAExternal < SecondaryBase
    self.table_name = "MConvODA"
    self.primary_key = "MConvODAId"
  end

  class MConvPFacExternal < SecondaryBase
    self.table_name = "MConvPFac"
    self.primary_key = "MConvPFacId"
  end

  class MConvPlazoExternal < SecondaryBase
    self.table_name = "MConvPlazo"
    self.primary_key = "MConvPlazoId"
  end

  class MConvTipoExternal < SecondaryBase
    self.table_name = "MConvTipo"
    self.primary_key = "MConvTipoId"
  end

  class MConvTipoDesctoExternal < SecondaryBase
    self.table_name = "MConvTipoDescto"
    self.primary_key = "MConvTipoDesctoId"
  end

  class MinincoExternal < SecondaryBase
    self.table_name = "Mininco"
  end

  class MinincoAreaExternal < SecondaryBase
    self.table_name = "MinincoArea"
  end

  class ModeloExternal < SecondaryBase
    self.table_name = "Modelo"
    self.primary_key = "ModeloId"
  end

  class NotaExternal < SecondaryBase
    self.table_name = "Nota"
    self.primary_key = "NotaId"
  end

  class ParameterExternal < SecondaryBase
    self.table_name = "Parameter"
  end

  class SecFunctionalityExternal < SecondaryBase
    self.table_name = "SecFunctionality"
    self.primary_key = "SecFunctionalityId"
  end

  class SecFunctionalityRoleExternal < SecondaryBase
    self.table_name = "SecFunctionalityRole"
  end

  class SecObjectExternal < SecondaryBase
    self.table_name = "SecObject"
  end

  class SecObjectFunctionalitiesExternal < SecondaryBase
    self.table_name = "SecObjectFunctionalities"
  end

  class SecRoleExternal < SecondaryBase
    self.table_name = "SecRole"
    self.primary_key = "SecRoleId"
  end

  class SecUserExternal < SecondaryBase
    self.table_name = "SecUser"
    self.primary_key = "SecUserId"
  end

  class SecUserAreaExternal < SecondaryBase
    self.table_name = "SecUserArea"
  end

  class SecUserManExternal < SecondaryBase
    self.table_name = "SecUserMan"
  end

  class SecUserManEmpExternal < SecondaryBase
    self.table_name = "SecUserManEmp"
  end

  class SecUserMultiEmpEmpExternal < SecondaryBase
    self.table_name = "SecUserMultiEmpEmp"
  end

  class SecUserMultiManManExternal < SecondaryBase
    self.table_name = "SecUserMultiManMan"
  end

  class SecUserRoleExternal < SecondaryBase
    self.table_name = "SecUserRole"
  end

  class SolicitudMaqExternal < SecondaryBase
    self.table_name = "SolicitudMaq"
    self.primary_key = "SolicitudMaqId"
  end

  class SolicitudMaqItemExternal < SecondaryBase
    self.table_name = "SolicitudMaqItem"
    self.primary_key = "SolicitudMaqItemId"
  end

  class TablaUFExternal < SecondaryBase
    self.table_name = "TablaUF"
  end

  class TipoVehiculoExternal < SecondaryBase
    self.table_name = "TipoVehiculo"
    self.primary_key = "TipoVehiculoId"
  end

  class UserCustomizationsExternal < SecondaryBase
    self.table_name = "UserCustomizations"
    self.primary_key = "UserCustomizationsId"
  end

  class ValorExternal < SecondaryBase
    self.table_name = "Valor"
    self.primary_key = "ValorId"
  end

  class VisitaExternal < SecondaryBase
    self.table_name = "Visita"
    self.primary_key = "VisitaId"
  end

  class VisitaItemExternal < SecondaryBase
    self.table_name = "VisitaItem"
    self.primary_key = "VisitaItemId"
  end

  class WWP_EntityExternal < SecondaryBase
    self.table_name = "WWP_Entity"
    self.primary_key = "WWPEntityId"
  end

  class WWP_MailExternal < SecondaryBase
    self.table_name = "WWP_Mail"
    self.primary_key = "WWPMailId"
  end

  class WWP_MailAttachmentsExternal < SecondaryBase
    self.table_name = "WWP_MailAttachments"
  end

  class WWP_MailTemplateExternal < SecondaryBase
    self.table_name = "WWP_MailTemplate"
  end

  class WWP_NotificationExternal < SecondaryBase
    self.table_name = "WWP_Notification"
    self.primary_key = "WWPNotificationId"
  end

  class WWP_NotificationDefinitionExternal < SecondaryBase
    self.table_name = "WWP_NotificationDefinition"
    self.primary_key = "WWPNotificationDefinitionId"
  end

  class WWP_SMSExternal < SecondaryBase
    self.table_name = "WWP_SMS"
    self.primary_key = "WWPSMSId"
  end

  class WWP_SubscriptionExternal < SecondaryBase
    self.table_name = "WWP_Subscription"
    self.primary_key = "WWPSubscriptionId"
  end

  class WWP_UserExtendedExternal < SecondaryBase
    self.table_name = "WWP_UserExtended"
    self.primary_key = "WWPUserExtendedId"
  end

  class WWP_WebClientExternal < SecondaryBase
    self.table_name = "WWP_WebClient"
    self.primary_key = "WWPWebClientId"
  end

  class WWP_WebNotificationExternal < SecondaryBase
    self.table_name = "WWP_WebNotification"
    self.primary_key = "WWPWebNotificationId"
  end
end
