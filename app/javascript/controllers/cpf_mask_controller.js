import { Controller } from "@hotwired/stimulus"

// Formats a CPF input as the operator types (000.000.000-00). Purely a display
// mask — Driver#cpf strips non-digits on normalize, so the masked value posts fine.
export default class extends Controller {
  format(event) {
    const input = event.target
    const digits = input.value.replace(/\D/g, "").slice(0, 11)

    input.value = digits
      .replace(/(\d{3})(\d)/, "$1.$2")
      .replace(/(\d{3})(\d)/, "$1.$2")
      .replace(/(\d{3})(\d{1,2})$/, "$1-$2")
  }
}
