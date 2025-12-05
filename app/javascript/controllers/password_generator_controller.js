import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  generate(e) {
    e.preventDefault()
    
    const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    const length = 16
    let password = ""
    
    for (let i = 0, n = charset.length; i < length; ++i) {
      password += charset.charAt(Math.floor(Math.random() * n))
    }

    this.inputTarget.value = password
    this.inputTarget.type = "text" 
    this.inputTarget.select()
  }
  
  toggleVisibility(e) {
    e.preventDefault()
    const type = this.inputTarget.type === "password" ? "text" : "password"
    this.inputTarget.type = type
  }
}