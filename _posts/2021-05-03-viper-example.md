---
title: Viper Example 1
categories:
    - go
feature_image: "https://picsum.photos/2560/600?image=872"
---

## 起源

之前在開發階段，只使用 env 很容易與其他專案搞混一起。所以有採用讀取特地檔案 `.env` 來協助處理。當初使用 [godotenv](https://github.com/joho/godotenv) 會自動讀取本地的 `.env` 檔。

後來漸漸發現有時要測試別的環境的設定時，需要抓取目標環境的 `.env`，但又不是每個環境變數都需要使用，又需要配合去更改......非常的不方便，有時還會遺漏。

此外，為了標示其環境變數的意義時，會在 `.env` 中後面直接打註解。我本身測試沒問題，以為其他人也不會有問題，但有些小夥伴們的開發環境會因為我在後面打的註解而導致讀取 `.env` 部分變數失敗。

為了改善服務配置的便利性及易讀性 (至少讓我可以在後面打註解啊!!!)，跳槽使用 `viper` 套件統一管理。最後 prod 環境中是採用 container，所以還是不捨棄環境變數，環境變數在這裡還是很方便的 wwwwww

最後我們期待程式能根據優先度高至低為 
1. flag
2. env
3. config file
4. default

## 開始實作

先來簡單的，flag 與 default 之間的優先度
```go
var (
	serverCmd = &cobra.Command{
		Run: func(cmd *cobra.Command, args []string) {
			vPort := viper.GetInt("port")
			fmt.Println("vport", vPort)
		},
    }
)

func main() {
	// setting flags
	var port int64
	flags := serverCmd.Flags()
	flags.Int64VarP(&port, "port", "p", 80, "listening port.")
	viper.BindPFlags(flags) // bind with cobra flags

	if err := serverCmd.Execute(); err != nil {
		panic(err)
	}
}
```
上面我們設置一個 port 的 flag，預設為 80。讓我們看看這樣的方式是否滿足我們想要的。
```go
> go run ./
vport 80
> go run ./ -p 81
vport 81
```
看起來蠻好的，接著加入環境變數
```diff
+import _ "github.com/joho/godotenv/autoload"

func main() {
+	viper.AutomaticEnv() // auto load env
	// setting flags
	var port int64
	flags := serverCmd.Flags()
	flags.Int64VarP(&port, "port", "p", 80, "listening port.")
	viper.BindPFlags(flags) // bind with cobra flags

	if err := serverCmd.Execute(); err != nil {
		panic(err)
	}
}
```
在這裡可以選擇是否要再加一個套件 [godotenv](https://github.com/joho/godotenv) 是否要讓他讀取本地的 `.env` 檔，因為 viper 並不會讀
```go
> set PORT=20
> go run ./
vport 20
> go run ./ -p 81
vport 81
```
接著導入相對微麻煩的 viper 讀檔的部分，可以設置檔案的內容格式，像是 json、yaml等。

記得設定設定檔的路徑，若有路徑有複數個， `AddConfigPath()` 就多打幾行

因我們期望沒讀到檔的話，程式還是可以去讀取其他地方，所以不能直接讓它直接 panic。
```diff
func main() {
	viper.AutomaticEnv() // auto load env

+	viper.SetConfigType("yaml") // setting config file type
+	viper.SetConfigName("config") // setting config file name
+	viper.AddConfigPath(".") // setting config file path
+	if err := viper.ReadInConfig(); err != nil {
+		// check error is not file not found
+		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
+			panic(err)
+		}
+	}
	// setting flags
	var port int64
	flags := serverCmd.Flags()
	flags.Int64VarP(&port, "port", "p", 80, "listening port.")
	viper.BindPFlags(flags) // bind with cobra flags

	if err := serverCmd.Execute(); err != nil {
		panic(err)
	}
}
```
設定檔的內容目前設置像這樣
```yaml
Port: 82

Database:
  Port: 3306
  Name: test
```
那要怎麼讀取咧? port 的話，照原本的方式沒問題，但是有像 Database 有巢狀結構的要如何是好。 viper 對於這巢狀的方式都使用 `.`。所以要取出資料庫的 port 時，就打 `viper.GetInt("database.port")` 就抓到了

我們測試一下目前的狀況
```go
> go run ./
vport 82
database port 3306
> go run ./ -p 83
vport 83
database port 3306
> set DATABASE_PORT=3307
> go run ./
vport 82
database port 3306
```
發現問題點了! 設了環境變數後沒抓到，反而還是讀取設定檔的值。

原來是我們剛剛上面說到的 `.` 要轉換成環境變數的 `_`。多加了這行就沒問題了。
```diff
func main() {
	viper.AutomaticEnv() // auto load env
+	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	viper.SetConfigType("yaml") // setting config file type
	viper.SetConfigName("config") // setting config file name
	viper.AddConfigPath(".") // setting config file path
	if err := viper.ReadInConfig(); err != nil {
		// check error is not file not found
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			panic(err)
		}
	}
	// setting flags
	var port int64
	flags := serverCmd.Flags()
	flags.Int64VarP(&port, "port", "p", 80, "listening port.")
	viper.BindPFlags(flags) // bind with cobra flags

	if err := serverCmd.Execute(); err != nil {
		panic(err)
	}
}
```

若覺得一個一個取值很麻煩的話，viper 也提供直接 Unmarshal 在一個 struct 中，若想知道這部分要怎麼使用的話可至我的 [範例](https://github.com/Li-AnLin/viper-example) 中參考。