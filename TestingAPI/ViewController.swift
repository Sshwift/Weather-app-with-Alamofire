import UIKit
import Alamofire
import SwiftyJSON
import CoreLocation
import SVProgressHUD

class ViewController: UIViewController {

    @IBOutlet private weak var timezoneLabel: UILabel!
    @IBOutlet private weak var humidityLabel: UILabel!
    @IBOutlet private weak var tempLabel: UILabel!
    @IBOutlet private weak var apparentTempLabel: UILabel!
    @IBOutlet private weak var iconImage: UIImageView!
    private let locationManager = CLLocationManager()
    private var errorLabel = UILabel()
    
    struct apiKeys {
        //TODO: НЕ ЗАБУДЬТЕ подставить сюда ключи от сервисов Dark Sky API и OpenCage API
        static let darkSkyKey = ""
        static let opencagedataKey = ""
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addErrorLabel()
        checkLocation()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    @objc func applicationDidBecomeActive() {
        checkLocationAuth()
    }
    
    func sendRequestWith(latitude: String, longitude: String) {
        
        let urlString = "https://api.darksky.net/forecast/\(apiKeys.darkSkyKey)/\(latitude),\(longitude)"
        let currentZoneURL = "https://api.opencagedata.com/geocode/v1/json?q=\(latitude)%2C%20\(longitude)&key=\(apiKeys.opencagedataKey)&language=ru&no_annotations=1"
        
        request(urlString).responseJSON { (response) in
            guard let rezult = response.result.value else {
                self.updateUIWhenSomethingGoneWrong(labelText: "Что-то не так с Dark Sky API 😭\n(возможно, неверный ключ)")
                return
            }
            let jsonResponse = JSON(rezult)
            
            let temperature = jsonResponse["currently"]["temperature"].doubleValue
            let humidity = jsonResponse["currently"]["humidity"].doubleValue
            let apparentTemperature = jsonResponse["currently"]["apparentTemperature"].doubleValue
            let icon = jsonResponse["currently"]["icon"].stringValue
            
            let currentWeather = Weather.init(temperature: temperature, humidity: humidity, apparentTemperature: apparentTemperature, icon: icon)
            
            self.updateUI(weather: currentWeather)
            
            requestCurrentZone()
        }
        
        func requestCurrentZone() {
            request(currentZoneURL).responseJSON { (response) in
                guard let rezult = response.result.value, response.response?.statusCode != 403 else {
                    self.updateUIWhenSomethingGoneWrong(labelText: "Что-то не так с OpenCage API 😭\n(возможно, неверный ключ)")
                    return
                }
                print(response.response?.statusCode)
                let jsonResponse = JSON(rezult)
                let country = jsonResponse["results"][0]["components"]["country"].stringValue
                let state = jsonResponse["results"][0]["components"]["state"].stringValue
                
                DispatchQueue.main.async {
                    self.timezoneLabel.text = "\(country), \(state)"
                }
                
            }
        }
        
    }
    
    func updateUI(weather: Weather) {
        DispatchQueue.main.async {
            self.hideUI(isHidden: false)
            self.humidityLabel.text = "Влажность: \(Int(100*weather.humidity))%"
            self.tempLabel.text = "\(Int((weather.temperature - 32) * 5/9))˚C"
            self.apparentTempLabel.text = "Ощущаемая: \(Int((weather.apparentTemperature - 32) * 5/9))˚C"
            self.iconImage.image = UIImage(named: weather.icon)
            SVProgressHUD.dismiss()
        }
    }
    
    func checkLocation() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
            checkLocationAuth()
        } else {
            updateUIWhenSomethingGoneWrong(labelText: "Нет доступа к геопозиции 😥")
        }
    }
    
    func updateUIWhenSomethingGoneWrong(labelText: String) {
        DispatchQueue.main.async {
            self.hideUI(isHidden: true)
            self.errorLabel.text = labelText
            SVProgressHUD.dismiss()
        }
    }
    
    func hideUI(isHidden: Bool) {
        timezoneLabel.isHidden = isHidden
        humidityLabel.isHidden = isHidden
        tempLabel.isHidden = isHidden
        apparentTempLabel.isHidden = isHidden
        iconImage.isHidden = isHidden
        errorLabel.isHidden = !isHidden
    }
    
    func addErrorLabel() {
        errorLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
        errorLabel.textColor = UIColor(red:0.12, green:0.12, blue:0.13, alpha:1.0)
        errorLabel.font = UIFont(name: "Avenir Next Medium", size: 20)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        view.addSubview(errorLabel)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.centerYAnchor.constraint(equalToSystemSpacingBelow: view.centerYAnchor, multiplier: 0).isActive = true
        errorLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: view.leadingAnchor, multiplier: 0).isActive = true
        errorLabel.trailingAnchor.constraint(equalToSystemSpacingAfter: view.trailingAnchor, multiplier: 0).isActive = true
    }
}

extension ViewController: CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latitude = locations.last?.coordinate.latitude  else { return }
        guard let longitude = locations.last?.coordinate.longitude else { return }
        self.sendRequestWith(latitude: "\(latitude)", longitude: "\(longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        updateUIWhenSomethingGoneWrong(labelText: "Что-то пошло не так ¯ \\ _ (ツ) _ / ¯ ")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuth()
    }
    
    func checkLocationAuth() {
        SVProgressHUD.show(withStatus: "Получаем данные 🤷‍♂️")
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied:
            updateUIWhenSomethingGoneWrong(labelText: "Предоставьте доступ к геопозиции.")
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            break
        case .authorizedAlways:
            break
        }
    }
}

