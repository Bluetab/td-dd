defprotocol Truedat.XLSX.BulkLoadProtocol do
  def get_opts(impl_for)
  def bulk_load_item(impl_for, data, ctx)
  def on_complete(impl_for, ids)
  def sheets_to_templates(impl_for, sheets)
end
