package cmd

import (
	"fmt"
	"log"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/vegaprotocol/devopstools/secrets"
	"github.com/vegaprotocol/devopstools/secrets/hcvault"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

type RootArgs struct {
	VegaNetworkName string
	Debug           bool
	Logger          *zap.Logger

	GitHubToken         string
	FileWithGitHubToken string
	HCVaultURL          string
	hcVaultSecretStore  *hcvault.HCVaultSecretStore
}

var rootArgs RootArgs

var rootCmd = &cobra.Command{
	Use:   "network-config",
	Short: "Manage networks config",
	Long:  `Manage networks config`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		var err error
		cfg := zap.NewProductionConfig()
		if rootArgs.Debug {
			cfg.Level.SetLevel(zap.DebugLevel)
		}
		cfg.Encoding = "console"
		cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
		rootArgs.Logger, err = cfg.Build()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to find latest checkpoint: %v\n", err)
			os.Exit(1)
		}
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Whoops. There was an error while executing your CLI '%s'", err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVar(&rootArgs.VegaNetworkName, "network", "", "Vega Network")
	if err := rootCmd.MarkPersistentFlagRequired("network"); err != nil {
		log.Fatalf("%v\n", err)
	}
	rootCmd.PersistentFlags().BoolVar(&rootArgs.Debug, "debug", false, "Print debug logs")
	rootCmd.PersistentFlags().StringVar(&rootArgs.GitHubToken, "github-token", viper.GetString("GITHUB_TOKEN"), "GitHub token to access HashiCorp Vault")
	rootCmd.PersistentFlags().StringVar(&rootArgs.FileWithGitHubToken, "github-token-file", "secret.txt", "file containing GitHub token to access HashiCorp Vault")
	rootCmd.PersistentFlags().StringVar(&rootArgs.HCVaultURL, "hc-vault-url", "https://vault.ops.vega.xyz", "url to HashiCorp Vault")
}

func (ra *RootArgs) getHCVaultSecretStore() (*hcvault.HCVaultSecretStore, error) {
	if ra.hcVaultSecretStore == nil {
		var err error
		ra.hcVaultSecretStore, err = hcvault.NewHCVaultSecretStore(
			ra.HCVaultURL,
			hcvault.HCVaultLoginToken{
				GitHubToken:         ra.GitHubToken,
				FileWithGitHubToken: ra.FileWithGitHubToken,
			},
		)
		if err != nil {
			return nil, err
		}
	}
	return ra.hcVaultSecretStore, nil

}

func (ra *RootArgs) GetNodeSecretStore() (secrets.NodeSecretStore, error) {
	return ra.getHCVaultSecretStore()
}
